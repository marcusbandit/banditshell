#!/usr/bin/env python3
"""The keyring's question, taken off gcr and handed to the shell."""

import base64
import ctypes
import json
import os
import secrets
import signal
import sys
import threading

import gi

gi.require_version("GLib", "2.0")
gi.require_version("Gio", "2.0")
from gi.repository import GLib, Gio  # noqa: E402

from cryptography.hazmat.primitives import hashes  # noqa: E402
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes  # noqa: E402
from cryptography.hazmat.primitives.kdf.hkdf import HKDF  # noqa: E402
from cryptography.hazmat.primitives.padding import PKCS7  # noqa: E402

PROMPTER_NAME = "org.gnome.keyring.SystemPrompter"

PRIVATE_NAME = "org.gnome.keyring.PrivatePrompter"

PROMPTER_PATH = "/org/gnome/keyring/Prompter"
CALLBACK_INTERFACE = "org.gnome.keyring.internal.Prompter.Callback"

PROMPTER_XML = """
<node>
  <interface name="org.gnome.keyring.internal.Prompter">
    <method name="BeginPrompting">
      <arg name="callback" type="o" direction="in"/>
    </method>
    <method name="PerformPrompt">
      <arg name="callback" type="o" direction="in"/>
      <arg name="type" type="s" direction="in"/>
      <arg name="properties" type="a{sv}" direction="in"/>
      <arg name="exchange" type="s" direction="in"/>
    </method>
    <method name="StopPrompting">
      <arg name="callback" type="o" direction="in"/>
    </method>
  </interface>
</node>
"""

REPLY_NONE = ""
REPLY_YES = "yes"
REPLY_NO = "no"

PRIME_1536 = int(
    "FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"
    "29024E088A67CC74020BBEA63B139B22514A08798E3404DD"
    "EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"
    "E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
    "EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D"
    "C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F"
    "83655D23DCA3AD961C62F356208552BB9ED529077096966D"
    "670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF",
    16,
)
GENERATOR = 2

PRIME_BYTES = (PRIME_1536.bit_length() + 7) // 8

PROTOCOL = "sx-aes-1"
KEY_LENGTH = 16
IV_LENGTH = 16
BLOCK = 16

def _b64encode(raw: bytes) -> str:
    return base64.b64encode(raw).decode("ascii")

def _boxed(value: "GLib.Variant") -> "GLib.Variant":
    """A property value wrapped the way the prompter has to send it back."""
    return GLib.Variant("v", value)

def _keyfile_write(fields: "dict[str, bytes]") -> str:
    """The exchange's wire form: a GKeyFile with one group and base64 values."""
    lines = [f"[{PROTOCOL}]"]
    lines += [f"{key}={_b64encode(value)}" for key, value in fields.items()]
    return "\n".join(lines) + "\n"

def _keyfile_read(text: str) -> "dict[str, bytes]":
    """The other direction, tolerant in the ways GKeyFile is."""
    out = {}
    group = None
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            group = line[1:-1]
            continue
        if group != PROTOCOL or "=" not in line:
            continue
        key, _, value = line.partition("=")
        try:
            out[key.strip()] = base64.b64decode(value.strip(), validate=True)
        except Exception:
            continue
    return out

class Exchange:
    """One side of a secret exchange, for the life of one prompt conversation."""

    def __init__(self) -> None:
        self._private = 0
        self._public = 0
        self._key = None

    def _generate(self) -> None:
        if self._private:
            return
        while True:
            private = secrets.randbits(PRIME_1536.bit_length() - 1)
            if private:
                break
        self._private = private
        self._public = pow(GENERATOR, private, PRIME_1536)

    @property
    def derived(self) -> bool:
        return self._key is not None

    def _public_bytes(self) -> bytes:
        return self._public.to_bytes((self._public.bit_length() + 7) // 8, "big")

    def begin(self) -> str:
        """Our public value, and nothing else. The opening move."""
        self._generate()
        return _keyfile_write({"public": self._public_bytes()})

    def receive(self, text: str) -> "bytes | None":
        """Take the peer's message: derive the key if we have not, then decrypt."""
        self._generate()
        fields = _keyfile_read(text)

        if not self.derived:
            peer = fields.get("public")
            if not peer:
                raise ValueError("secret exchange without a public key")
            self._derive(int.from_bytes(peer, "big"))

        if "secret" not in fields:
            return None
        return self._decrypt(fields["secret"], fields.get("iv", b""))

    def send(self, secret: "bytes | None") -> str:
        """Our reply, with the secret encrypted into it when there is one."""
        if not self.derived:
            raise ValueError("nothing has been received to reply to")
        fields = {"public": self._public_bytes()}
        if secret is not None:
            iv = os.urandom(IV_LENGTH)
            fields["secret"] = self._encrypt(secret, iv)
            fields["iv"] = iv
        return _keyfile_write(fields)

    def _derive(self, peer_public: int) -> None:
        shared = pow(peer_public, self._private, PRIME_1536)
        ikm = shared.to_bytes(PRIME_BYTES, "big")
        self._key = HKDF(
            algorithm=hashes.SHA256(), length=KEY_LENGTH, salt=None, info=None
        ).derive(ikm)

    def _encrypt(self, plain: bytes, iv: bytes) -> bytes:
        padder = PKCS7(BLOCK * 8).padder()
        padded = padder.update(plain) + padder.finalize()
        encryptor = Cipher(algorithms.AES(self._key), modes.CBC(iv)).encryptor()
        return encryptor.update(padded) + encryptor.finalize()

    def _decrypt(self, cipher: bytes, iv: bytes) -> bytes:
        if len(iv) != IV_LENGTH or len(cipher) % BLOCK:
            raise ValueError("secret exchange with a malformed ciphertext")
        decryptor = Cipher(algorithms.AES(self._key), modes.CBC(iv)).decryptor()
        padded = decryptor.update(cipher) + decryptor.finalize()
        unpadder = PKCS7(BLOCK * 8).unpadder()
        return unpadder.update(padded) + unpadder.finalize()

class Pipe:
    """The line protocol with services/Keyring.qml."""

    def __init__(self, on_answer) -> None:
        self._on_answer = on_answer
        self._lock = threading.Lock()

    def send(self, **message) -> None:
        line = json.dumps(message, separators=(",", ":"))
        with self._lock:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()

    def listen(self) -> None:
        """Read stdin forever, on a thread of its own."""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except ValueError:
                continue
            GLib.idle_add(self._deliver, message)
        GLib.idle_add(self._deliver, None)

    def _deliver(self, message) -> bool:
        self._on_answer(message)
        return GLib.SOURCE_REMOVE

class Conversation:
    """One client's prompting session: a bus name, a callback path, a key."""

    def __init__(self, sender: str, path: str) -> None:
        self.sender = sender
        self.path = path
        self.exchange = Exchange()
        self.properties = {}
        self.kind = ""
        self.showing = False
        self.watch = 0

    @property
    def key(self) -> "tuple[str, str]":
        return (self.sender, self.path)

class Prompter:
    def __init__(self, connection: Gio.DBusConnection) -> None:
        self._bus = connection
        self._conversations = {}
        self._active = None
        self._waiting = []
        self._serial = 0
        self._pipe = Pipe(self._answered)

    def _later(self, action) -> None:
        """Run this once the method handler that asked for it has returned."""
        GLib.idle_add(lambda: (action(), GLib.SOURCE_REMOVE)[1])

    def method(self, _conn, sender, _path, _iface, method, params, invocation):
        try:
            if method == "BeginPrompting":
                self._begin(sender, params[0])
            elif method == "PerformPrompt":
                self._perform(sender, params[0], params[1], params[2], params[3])
            elif method == "StopPrompting":
                self._stop(sender, params[0], tell_client=True)
            else:
                invocation.return_error_literal(
                    Gio.dbus_error_quark(),
                    Gio.DBusError.UNKNOWN_METHOD,
                    f"no such method: {method}",
                )
                return
        except Exception as error:  # the bus must always get an answer
            invocation.return_error_literal(
                Gio.dbus_error_quark(), Gio.DBusError.FAILED, str(error)
            )
            return
        invocation.return_value(None)

    def _begin(self, sender, path) -> None:
        conversation = Conversation(sender, path)
        if conversation.key in self._conversations:
            raise ValueError("already prompting for this callback")

        self._conversations[conversation.key] = conversation
        conversation.watch = Gio.bus_watch_name_on_connection(
            self._bus,
            sender,
            Gio.BusNameWatcherFlags.NONE,
            None,
            lambda *_: self._vanished(sender),
        )
        self._waiting.append(conversation)
        self._later(self._advance)

    def _perform(self, sender, path, kind, properties, exchange) -> None:
        conversation = self._conversations.get((sender, path))
        if conversation is None:
            raise ValueError("not begun prompting for this callback")
        if conversation is not self._active:
            raise ValueError("not this callback's turn to prompt")
        if conversation.showing:
            raise ValueError("already performing a prompt for this callback")
        if kind not in ("password", "confirm"):
            raise ValueError(f"invalid type of prompt: {kind}")

        conversation.exchange.receive(exchange)
        conversation.kind = kind
        for name, value in properties.items():
            conversation.properties[name] = value

        conversation.showing = True
        self._serial += 1
        self._show(conversation)

    def _stop(self, sender, path, tell_client) -> None:
        conversation = self._conversations.pop((sender, path), None)
        if conversation is None:
            return

        if conversation.watch:
            Gio.bus_unwatch_name(conversation.watch)
        if conversation in self._waiting:
            self._waiting.remove(conversation)

        if conversation is self._active:
            self._active = None
            if conversation.showing:
                self._pipe.send(event="hide", id=self._serial)
            conversation.showing = False

        if tell_client:
            self._call(conversation, "PromptDone", GLib.Variant("()", ()))

        self._later(self._advance)

    def _vanished(self, sender) -> None:
        for key in [k for k in self._conversations if k[0] == sender]:
            self._stop(key[0], key[1], tell_client=False)

    def _advance(self) -> None:
        """Give the screen to the next conversation waiting for it."""
        if self._active is not None or not self._waiting:
            return
        self._active = self._waiting.pop(0)
        self._ready(self._active, REPLY_NONE, None)

    def _ready(self, conversation, reply, secret) -> None:
        exchange = conversation.exchange
        payload = exchange.begin() if not exchange.derived else exchange.send(secret)

        changed = {}
        if conversation.properties.get("choice-label"):
            chosen = conversation.properties.get("choice-chosen", False)
            changed["choice-chosen"] = _boxed(GLib.Variant("b", bool(chosen)))

        self._call(
            conversation,
            "PromptReady",
            GLib.Variant("(sa{sv}s)", (reply, changed, payload)),
        )

    def _call(self, conversation, method, parameters) -> None:
        self._bus.call(
            conversation.sender,
            conversation.path,
            CALLBACK_INTERFACE,
            method,
            parameters,
            None,
            Gio.DBusCallFlags.NO_AUTO_START,
            -1,
            None,
            None,
        )

    def _show(self, conversation) -> None:
        properties = conversation.properties

        def text(name):
            value = properties.get(name, "")
            return value if isinstance(value, str) else ""

        def flag(name):
            return bool(properties.get(name, False))

        self._pipe.send(
            event="show",
            id=self._serial,
            kind=conversation.kind,
            title=text("title"),
            message=text("message"),
            description=text("description"),
            warning=text("warning"),
            choiceLabel=text("choice-label"),
            choiceChosen=flag("choice-chosen"),
            passwordNew=flag("password-new"),
            continueLabel=text("continue-label"),
            cancelLabel=text("cancel-label"),
        )

    def _answered(self, message) -> None:
        if message is None:
            for conversation in list(self._conversations.values()):
                if conversation is self._active and conversation.showing:
                    self._settle(conversation, REPLY_NO, None, {})
            loop.quit()
            return

        conversation = self._active
        if conversation is None or not conversation.showing:
            return
        if message.get("id") != self._serial:
            return

        changed = {}
        if conversation.properties.get("choice-label"):
            chosen = bool(message.get("choice", False))
            conversation.properties["choice-chosen"] = chosen
            changed["choice-chosen"] = _boxed(GLib.Variant("b", chosen))

        if message.get("reply") != REPLY_YES:
            self._settle(conversation, REPLY_NO, None, changed)
            return

        if conversation.kind == "confirm":
            self._settle(conversation, REPLY_YES, None, changed)
            return

        secret = message.get("secret", "")
        self._settle(conversation, REPLY_YES, secret.encode("utf-8"), changed)

    def _settle(self, conversation, reply, secret, changed) -> None:
        conversation.showing = False
        self._pipe.send(event="hide", id=self._serial)

        exchange = conversation.exchange
        payload = exchange.send(secret)
        self._call(
            conversation,
            "PromptReady",
            GLib.Variant("(sa{sv}s)", (reply, changed, payload)),
        )

    def start_listening(self) -> None:
        thread = threading.Thread(target=self._pipe.listen, daemon=True)
        thread.start()

EXIT_LOST_NAME = 3

_exit_code = 0

def _lost(name) -> None:
    global _exit_code
    _exit_code = EXIT_LOST_NAME
    print(f"keyring-prompter: lost {name}", file=sys.stderr)
    loop.quit()

def main() -> int:
    global loop
    loop = GLib.MainLoop()

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    prompter = Prompter(bus)

    info = Gio.DBusNodeInfo.new_for_xml(PROMPTER_XML)
    bus.register_object(
        PROMPTER_PATH, info.interfaces[0], prompter.method, None, None
    )

    flags = (
        Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT
    )
    for name in (PROMPTER_NAME, PRIVATE_NAME):
        Gio.bus_own_name_on_connection(
            bus, name, flags, None, lambda _c, n: _lost(n)
        )

    prompter.start_listening()

    for sig in (signal.SIGINT, signal.SIGTERM):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, lambda: (loop.quit(), True)[1])

    loop.run()
    return _exit_code

class _PyGObject(ctypes.Structure):
    """Where PyGObject keeps the C pointer inside a Python wrapper."""

    _fields_ = [
        ("head", ctypes.c_byte * object.__basicsize__),
        ("obj", ctypes.c_void_p),
    ]

def selftest() -> int:
    """Hold a whole conversation with gcr's own implementation."""
    gi.require_version("Gcr", "3")
    from gi.repository import Gcr

    lib = ctypes.CDLL("libgcr-base-3.so.1")
    lib.gcr_secret_exchange_get_secret.restype = ctypes.POINTER(ctypes.c_char)
    lib.gcr_secret_exchange_get_secret.argtypes = [
        ctypes.c_void_p,
        ctypes.POINTER(ctypes.c_size_t),
    ]

    def their_secret(exchange) -> bytes:
        length = ctypes.c_size_t(0)
        raw = lib.gcr_secret_exchange_get_secret(
            _PyGObject.from_address(id(exchange)).obj, ctypes.byref(length)
        )
        return ctypes.string_at(raw, length.value)

    rounds = 64
    for index in range(rounds):
        theirs = Gcr.SecretExchange.new(None)
        ours = Exchange()

        opening = theirs.begin()
        if ours.receive(opening) is not None:
            print("selftest: the opening carried a secret", file=sys.stderr)
            return 1

        password = f"correct horse battery staple {index}".encode("utf-8")
        if not theirs.receive(ours.send(password)):
            print("selftest: gcr rejected our reply", file=sys.stderr)
            return 1

        got = their_secret(theirs)
        if got != password:
            print(f"selftest: gcr read back {got!r}", file=sys.stderr)
            return 1

        back = f"and back again {index}"
        if ours.receive(theirs.send(back, -1)) != back.encode("utf-8"):
            print("selftest: we could not read gcr's secret", file=sys.stderr)
            return 1

    print(f"selftest: {rounds} exchanges agreed with gcr, both directions")
    return 0

if __name__ == "__main__":
    if "--selftest" in sys.argv[1:]:
        sys.exit(selftest())
    sys.exit(main())
