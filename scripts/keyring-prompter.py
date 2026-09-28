#!/usr/bin/env python3
"""The keyring's question, taken off gcr and handed to the shell.

WHAT THIS REPLACES. When gnome-keyring needs a passphrase - to unlock a keyring,
to hand an application a stored secret, to confirm something about a certificate
- it does not draw anything. It looks up the bus name
`org.gnome.keyring.SystemPrompter` and asks whoever owns it to do the asking.
Nobody owns it at rest, so D-Bus activates `/usr/lib/gcr-prompter`, which is a
GTK dialog: a grey box in Cantarell that floats over the desktop on whichever
workspace it landed on, looking like nothing else on this machine. This program
owns that name instead, so the request arrives HERE and the shell draws it.

    gnome-keyring-daemon  --BeginPrompting-->  this  --stdout-->  the shell
                          <---PromptReady---         <--stdin---

WHY A PROCESS AND NOT QML. Quickshell 0.3 can consume D-Bus in a few blessed
shapes (a tray, MPRIS, notifications) and cannot EXPORT one: there is no way for
QML to own a bus name or answer a method call, and this whole protocol is the
shell being called. So the bus side lives here and the two talk over the pipe
that Quickshell's Process already gives us. See services/Keyring.qml.

THE SECRET'S PATH THROUGH THIS PROGRAM, because it is the thing worth auditing.
It arrives on stdin from the shell, is encrypted into the exchange below, and
goes out over the bus. It is never written to a file, never put in an argument,
never printed, and never held after the reply is built. stdout carries the
QUESTION only; nothing a secret could be in ever travels that way. The pipe
itself is a parent-child pipe between two processes of the same user, which is
the same trust boundary services/Lock.qml already holds a PAM password across.

THE SECRET EXCHANGE is not decoration and cannot be skipped. gnome-keyring will
not accept a password as a plain string over the bus; both sides run a
Diffie-Hellman key agreement and the password crosses encrypted, so that the
message bus - and anything with a right to watch it - never sees it. The scheme
is gcr's `sx-aes-1` and is reimplemented here exactly, because "close enough" is
a passphrase the daemon rejects rather than an error anyone can read:

    key agreement   Diffie-Hellman over the 1536-bit IKE group (RFC 3526 group 5)
    shared secret   the raw DH value, LEFT-PADDED with zeros to the prime's
                    192 bytes - gcr pads and a minimal encoding would derive a
                    different key on one exchange in about 256
    key derivation  HKDF-SHA256, no salt, no info, 16 bytes out
    transport       AES-128-CBC with a fresh random IV and PKCS#7 padding
    on the wire     a GKeyFile: "[sx-aes-1]" and then base64 `public`,
                    `secret` and `iv` lines

`--selftest` checks that reimplementation against the real thing rather than
against a memory of it: gcr ships a GObject-introspected `GcrSecretExchange`, so
the test runs a whole conversation with the library this has to convince and
fails loudly if a byte of it has drifted.

WHAT IS DELIBERATELY NOT HANDLED. `caller-window` names the X11/Wayland window
that asked, so a dialog can be made transient for it. The shell draws on its own
surface over everything, so there is nothing to be transient for and the
property is read and dropped.
"""

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

# ---------------------------------------------------------------- the names --
#
# All four constants are gcr's own, from gcr/gcr-dbus-constants.h, and the
# interface is verbatim gcr/org.gnome.keyring.Prompter.xml. Nothing here may be
# "tidied": the daemon looks these up by string.

PROMPTER_NAME = "org.gnome.keyring.SystemPrompter"

# The second name gcr registers for the same binary. gnome-keyring normally
# reaches its private prompter over a peer-to-peer connection rather than the
# session bus, so this is unlikely ever to be called; it is claimed anyway so
# that a daemon which DOES ask for it on the session bus cannot fall through to
# activating the GTK dialog behind the shell's back.
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

# The three answers a prompt can carry back. "" is not "no": it is the FIRST
# PromptReady, the one that only says the prompter is awake and carries the
# opening half of the key agreement.
REPLY_NONE = ""
REPLY_YES = "yes"
REPLY_NO = "no"

# ------------------------------------------------------------- the exchange --

# RFC 3526 group 5, which egg/egg-dh.c calls "ietf-ike-grp-modp-1536". The
# generator is 2.
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

# The prime's own length, and therefore the shared secret's. 1536 bits.
PRIME_BYTES = (PRIME_1536.bit_length() + 7) // 8

PROTOCOL = "sx-aes-1"
KEY_LENGTH = 16
IV_LENGTH = 16
BLOCK = 16


def _b64encode(raw: bytes) -> str:
    return base64.b64encode(raw).decode("ascii")


def _boxed(value: "GLib.Variant") -> "GLib.Variant":
    """A property value wrapped the way the prompter has to send it back.

    THE PROTOCOL IS NOT SYMMETRIC HERE, and it costs an afternoon to find out
    the hard way. Both directions carry `a{sv}`, but the two sides fill the `v`
    differently: the client puts the value straight in
    (`build_dirty_properties` in gcr/gcr-system-prompt.c), while the prompter
    boxes it once more (`g_variant_new_variant` in prompt_build_properties, in
    gcr/gcr-system-prompter.c) because the client unboxes twice on the way in
    (`g_variant_get_variant`, update_properties_from_iter). So what we READ is a
    plain string or bool, and what we WRITE has to be a variant holding a
    variant. Sending it singly boxed is not a hard error: the client logs a
    `g_variant_get_variant` assertion nobody sees and quietly keeps the old
    value, so the box someone ticked simply does not stick.
    """
    return GLib.Variant("v", value)


def _keyfile_write(fields: "dict[str, bytes]") -> str:
    """The exchange's wire form: a GKeyFile with one group and base64 values.

    Written by hand rather than through GLib.KeyFile so that the output is
    exactly what gcr's `g_key_file_to_data` plus `g_strchug` produces - group
    line, one `key=value` per field, trailing newline - with no comment header
    and no locale suffixes to go wrong.
    """
    lines = [f"[{PROTOCOL}]"]
    lines += [f"{key}={_b64encode(value)}" for key, value in fields.items()]
    return "\n".join(lines) + "\n"


def _keyfile_read(text: str) -> "dict[str, bytes]":
    """The other direction, tolerant in the ways GKeyFile is.

    GKeyFile ignores blank lines and comments and strips the whitespace around
    the `=`, so this does too. A field that is not valid base64 is dropped
    rather than raised on: it is a field we then treat as absent, which is the
    same thing gcr does with one it cannot decode.
    """
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
    """One side of a secret exchange, for the life of one prompt conversation.

    It is per conversation and not per message on purpose: gnome-keyring reuses
    the same exchange across a wrong-password retry, so the key is derived once
    and the second question is encrypted under the same one.
    """

    def __init__(self) -> None:
        self._private = 0
        self._public = 0
        self._key = None

    def _generate(self) -> None:
        if self._private:
            return
        # egg_dh_gen_pair asks for as many bits as the prime and then clears
        # everything at or above bit 1535, so the private value is in
        # [1, 2^1535). Matched here, though the peer cannot tell either way:
        # it only ever sees g^x.
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
        # MINIMAL big-endian, which is libgcrypt's GCRYMPI_FMT_USG and what
        # egg_dh_pubkey_export hands over. The peer scans it back into an
        # integer, so a longer zero-padded form would also parse; this is
        # written the way gcr writes it because the wire is the one place the
        # two implementations are compared.
        return self._public.to_bytes((self._public.bit_length() + 7) // 8, "big")

    def begin(self) -> str:
        """Our public value, and nothing else. The opening move."""
        self._generate()
        return _keyfile_write({"public": self._public_bytes()})

    def receive(self, text: str) -> "bytes | None":
        """Take the peer's message: derive the key if we have not, then decrypt.

        Returns the secret it carried, or None when it carried none, which is
        the ordinary case for the message that only completes the agreement.
        Raises ValueError when the message cannot be used at all, because a
        conversation whose key is wrong can never produce anything but wrong
        passwords and has to fail where it went wrong.
        """
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
        # LEFT-PADDED TO THE PRIME'S LENGTH, which is the one place a plausible
        # implementation silently disagrees with gcr. egg_dh_gen_secret prints
        # the value and then memmoves it up against a buffer the size of the
        # prime, so a shared value that happens to be short is hashed WITH its
        # leading zeros. Dropping them derives a different key roughly one
        # exchange in 256, which would look like an intermittently wrong
        # password and nothing else.
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


# ---------------------------------------------------------------- the shell --


class Pipe:
    """The line protocol with services/Keyring.qml.

    One JSON object per line each way. Out goes `show` and `hide`; back comes
    `answer`. stdout is line-buffered and flushed on every write, because the
    reader on the other end is a SplitParser waiting on a newline and a question
    sitting in a buffer is a prompt that never appears.
    """

    def __init__(self, on_answer) -> None:
        self._on_answer = on_answer
        self._lock = threading.Lock()

    def send(self, **message) -> None:
        line = json.dumps(message, separators=(",", ":"))
        with self._lock:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()

    def listen(self) -> None:
        """Read stdin forever, on a thread of its own.

        A thread rather than a GLib IO watch because the reply carries a
        password: keeping it in one straight-line read and handing it
        immediately to the main loop is easier to audit than a watch that owns a
        growing buffer. The handler is bounced onto the main loop, so everything
        that touches prompt state still happens on one thread.
        """
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except ValueError:
                continue
            GLib.idle_add(self._deliver, message)
        # The shell closed the pipe, which means the shell is gone. Anything we
        # are holding open is a prompt nobody can answer.
        GLib.idle_add(self._deliver, None)

    def _deliver(self, message) -> bool:
        self._on_answer(message)
        return GLib.SOURCE_REMOVE


# -------------------------------------------------------------- the prompts --


class Conversation:
    """One client's prompting session: a bus name, a callback path, a key.

    gnome-keyring opens one of these per thing it wants to ask about and may
    ask several questions down it (a wrong password is the same conversation
    asked again), so the exchange and the properties both live for as long as
    the client keeps it open rather than for one question.
    """

    def __init__(self, sender: str, path: str) -> None:
        self.sender = sender
        self.path = path
        self.exchange = Exchange()
        # Properties ACCUMULATE. Each PerformPrompt carries only what CHANGED
        # since the last one, so a retry that only sets `warning` would blank
        # the title if these were replaced rather than merged.
        self.properties = {}
        self.kind = ""
        # Whether a question is currently on the shell's screen.
        self.showing = False
        self.watch = 0

    @property
    def key(self) -> "tuple[str, str]":
        return (self.sender, self.path)


class Prompter:
    def __init__(self, connection: Gio.DBusConnection) -> None:
        self._bus = connection
        self._conversations = {}
        # Which conversation is on screen. ONE AT A TIME, which is gcr's own
        # SINGLE mode: two password fields on one screen is two ways to type the
        # wrong secret into the wrong question. The rest wait, and each is begun
        # only when it reaches the front, so a client that gives up while queued
        # is dropped without ever having drawn anything.
        self._active = None
        self._waiting = []
        self._serial = 0
        self._pipe = Pipe(self._answered)

    def _later(self, action) -> None:
        """Run this once the method handler that asked for it has returned.

        The whole of the ordering contract with gcr's client, in one line. See
        the note in _begin for what goes wrong without it.
        """
        GLib.idle_add(lambda: (action(), GLib.SOURCE_REMOVE)[1])

    # -- the bus side ----------------------------------------------------

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
        # A client that dies mid-prompt leaves a question on screen that nothing
        # is listening for the answer to. Watching the name is the only way to
        # hear about that: the bus notices the disconnect, we never would.
        conversation.watch = Gio.bus_watch_name_on_connection(
            self._bus,
            sender,
            Gio.BusNameWatcherFlags.NONE,
            None,
            lambda *_: self._vanished(sender),
        )
        self._waiting.append(conversation)
        # AFTER THE REPLY, NEVER BEFORE IT, and this is not a stylistic
        # preference: gcr's client installs the async result it uses to receive
        # PromptReady only once BeginPrompting has RETURNED, so a prompter that
        # readies from inside the method handler arrives at a client with
        # nowhere to put it. It fails as
        #     prompt_method_ready: assertion 'G_IS_SIMPLE_ASYNC_RESULT (pending)'
        # on the caller's side and as a prompt that simply never appears on
        # ours. gcr's own prompter returns the invocation first and then calls
        # prompt_next_ready; the idle here is how a method handler that returns
        # at the END of the function does the same thing.
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

        # Deferred for the reason _begin spells out: whatever comes next begins
        # with a PromptReady to somebody, and a PromptReady must never overtake
        # the reply to the method that made room for it.
        self._later(self._advance)

    def _vanished(self, sender) -> None:
        for key in [k for k in self._conversations if k[0] == sender]:
            # No PromptDone: the thing it would be sent to is what vanished.
            self._stop(key[0], key[1], tell_client=False)

    def _advance(self) -> None:
        """Give the screen to the next conversation waiting for it."""
        if self._active is not None or not self._waiting:
            return
        self._active = self._waiting.pop(0)
        # The first PromptReady says only "the prompter is awake", and carries
        # the opening half of the key agreement. There is nothing to draw yet:
        # what the question SAYS arrives with the PerformPrompt this invites.
        self._ready(self._active, REPLY_NONE, None)

    def _ready(self, conversation, reply, secret) -> None:
        exchange = conversation.exchange
        payload = exchange.begin() if not exchange.derived else exchange.send(secret)

        # Only the properties the prompt itself can change. Everything else on a
        # GcrPrompt is the client telling US something, and echoing it back
        # would be this program inventing facts about someone else's dialog.
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
        # NO_AUTO_START, like gcr: the callback lives in a process that is
        # already running by definition, and activating something to receive it
        # would only ever be activating the wrong thing. Fire and forget, with
        # the reply dropped: a client that has gone away is handled by the name
        # watch above, and a prompter that blocked on it would be a shell that
        # stopped drawing because someone else stopped answering.
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

    # -- the shell side --------------------------------------------------

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
        # The pipe closed: the shell is gone, and every question on the bus is
        # now unanswerable. Say no to all of them rather than leaving callers
        # blocked on a prompter with no screen.
        if message is None:
            for conversation in list(self._conversations.values()):
                if conversation is self._active and conversation.showing:
                    self._settle(conversation, REPLY_NO, None, {})
            loop.quit()
            return

        conversation = self._active
        if conversation is None or not conversation.showing:
            return
        # The serial is the whole of the staleness check: an answer typed into a
        # question that has since been withdrawn arrives with the old number and
        # is dropped, rather than being applied to whatever is on screen now.
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


# ------------------------------------------------------------------ the run --


# WHY LEAVING IS WORTH A DISTINCT EXIT CODE. There are two ways this program
# stops, and the shell has to tell them apart: the pipe closing means the shell
# itself is going away and there is nothing to restart, while losing the bus
# name means something else is prompting and this one should come back and try
# again once that something has finished. See services/Keyring.qml, which
# retries on 3 and on nothing else.
EXIT_LOST_NAME = 3

_exit_code = 0


def _lost(name) -> None:
    # Somebody else owns the name. The usual cause is not a second shell: it is
    # gcr-prompter, which D-Bus activated while the shell was not running and
    # which refuses to be replaced. It leaves of its own accord once it is idle,
    # so this is a "come back shortly" rather than a failure.
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

    # REPLACE so that a shell restart takes the name back from whatever holds
    # it, and ALLOW_REPLACEMENT so the next restart can do the same to us. The
    # ordinary case needs neither: the shell starts at login, long before
    # anything asks for a keyring, so the name is simply free.
    flags = (
        Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT
    )
    for name in (PROMPTER_NAME, PRIVATE_NAME):
        Gio.bus_own_name_on_connection(
            bus, name, flags, None, lambda _c, n: _lost(n)
        )

    prompter.start_listening()

    # SIGINT and SIGTERM through the loop rather than through Python's default
    # handler, which cannot interrupt a GLib main loop and would leave the
    # process alive holding the bus name after the shell had let go of it.
    for sig in (signal.SIGINT, signal.SIGTERM):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, lambda: (loop.quit(), True)[1])

    loop.run()
    return _exit_code


# ----------------------------------------------------------------- the test --


class _PyGObject(ctypes.Structure):
    """Where PyGObject keeps the C pointer inside a Python wrapper.

    Needed by the selftest alone, for the one gcr function whose introspection
    is unusable: `gcr_secret_exchange_get_secret` returns a pointer with the
    length in an out parameter, and calling it through gi SEGFAULTS the
    interpreter on both Gcr-3 and Gcr-4. Reading it through ctypes is the only
    way to see what gcr actually decrypted, and seeing that is the whole point
    of the test - "gcr did not raise" is a much weaker claim than "gcr got the
    password back byte for byte".
    """

    _fields_ = [
        ("head", ctypes.c_byte * object.__basicsize__),
        ("obj", ctypes.c_void_p),
    ]


def selftest() -> int:
    """Hold a whole conversation with gcr's own implementation.

    This is the only check that means anything: the exchange above exists to
    convince `libgcr`, so it is `libgcr` that has to be convinced. Both
    directions are exercised, because the two failures they catch are
    different - gcr reading our secret back wrong is a password the daemon
    rejects, and us reading gcr's wrong is a question we cannot even parse -
    and the run is repeated enough times that the short-shared-value case the
    zero padding exists for is overwhelmingly likely to have come up.
    """
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

        # Their opening, our reply, their reading of it.
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

        # And the other direction: a secret THEY encrypt has to come out here,
        # which is the path every question after the first one takes.
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
