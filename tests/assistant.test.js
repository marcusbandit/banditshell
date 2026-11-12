const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Assistant = lib("services/assistant.js", ["askOf", "looksLikeQuestion", "chatRequest", "listRequest", "pullRequest", "readModels", "readChunk", "splitStatus", "failureText", "visibleText", "tidyRewrite", "readPull", "pullTotals", "sizeText", "snippet", "trimTurns", "undash", "keySafe", "keyFor", "keyless", "officialOpenai", "webLink", "lineBreaks", "typeBackRefusal", "modelFor", "isLocal", "actionOf", "ACTIONS", "STARTER", "rewriteMessage", "rewritePrompt", "agentCommand", "agentPrompt", "agentFailure", "readCodexModels", "signedOut", "modelLabel", "askPrompt", "withContext", "windowContext", "droppedTurns", "extendSummary", "transcript", "askModel", "nextModel"]);

const settings = {
    model: "m",
    ollamaAddress: "http://localhost:11434/",
    openaiAddress: "https://api.example.com/v1/"
};

test.describe("assistant: what counts as asking", () => {
    test.it("reads a question after ? or ask", () => {
        assert.strictEqual(Assistant.askOf("? why is the sky blue"), "why is the sky blue");
        assert.strictEqual(Assistant.askOf("?why"), "why");
        assert.strictEqual(Assistant.askOf("ask how tall is everest"), "how tall is everest");
        assert.strictEqual(Assistant.askOf("?"), "");
        assert.strictEqual(Assistant.askOf("ask"), "");
    });

    test.it("leaves words that only start like ask alone", () => {
        assert.strictEqual(Assistant.askOf("asking"), null);
        assert.strictEqual(Assistant.askOf("firefox"), null);
        assert.strictEqual(Assistant.askOf("a ? b"), null);
    });

    test.it("spots a question typed without a prefix", () => {
        assert.ok(Assistant.looksLikeQuestion("why is the sky blue"));
        assert.ok(Assistant.looksLikeQuestion("how do magnets work"));
        assert.ok(Assistant.looksLikeQuestion("is it going to rain?"));
        assert.ok(Assistant.looksLikeQuestion("explain entropy"));
        assert.ok(!Assistant.looksLikeQuestion("why"));
        assert.ok(!Assistant.looksLikeQuestion("what day"));
        assert.ok(!Assistant.looksLikeQuestion("do not disturb"));
        assert.ok(!Assistant.looksLikeQuestion("firefox"));
    });
});

test.describe("assistant: requests", () => {
    const messages = [{ role: "user", content: "hi" }];

    test.it("asks Ollama to stream without thinking, the system prompt first", () => {
        const request = Assistant.chatRequest("ollama", settings, "be brief", messages);
        assert.strictEqual(request.url, "http://localhost:11434/api/chat");
        assert.strictEqual(request.auth, "");
        const body = JSON.parse(request.body);
        assert.strictEqual(body.stream, true);
        assert.strictEqual(body.think, false);
        assert.deepStrictEqual(body.messages[0], { role: "system", content: "be brief" });
        assert.strictEqual(body.messages[1].content, "hi");
    });

    test.it("puts the key behind an auth prefix, never in the request itself", () => {
        const openai = Assistant.chatRequest("openai", settings, "s", messages);
        assert.strictEqual(openai.url, "https://api.example.com/v1/chat/completions");
        assert.strictEqual(openai.auth, "Authorization: Bearer ");
        assert.strictEqual(openai.body.indexOf("sk-"), -1);
    });

    test.it("lists models where each backend keeps them", () => {
        assert.strictEqual(Assistant.listRequest("ollama", settings).url, "http://localhost:11434/api/tags");
        assert.strictEqual(Assistant.listRequest("openai", settings).url, "https://api.example.com/v1/models");
        assert.strictEqual(JSON.parse(Assistant.pullRequest(settings, "x").body).model, "x");
    });

    test.it("reads model lists", () => {
        assert.deepStrictEqual(Assistant.readModels("ollama", '{"models":[{"name":"a:1"},{"model":"b"}]}'), ["a:1", "b"]);
        assert.deepStrictEqual(Assistant.readModels("openai", '{"data":[{"id":"gpt-x"}]}'), ["gpt-x"]);
        assert.strictEqual(Assistant.readModels("ollama", "<html>"), null);
    });

    test.it("picks a model that exists", () => {
        assert.strictEqual(Assistant.modelFor("ollama", "", ["x", Assistant.STARTER.name]), Assistant.STARTER.name);
        assert.strictEqual(Assistant.modelFor("ollama", "gone", ["x"]), "x");
        assert.strictEqual(Assistant.modelFor("ollama", "x", ["x", "y"]), "x");
        assert.strictEqual(Assistant.modelFor("ollama", "", []), "");
        assert.strictEqual(Assistant.modelFor("openai", "", ["gpt-big", "gpt-mini"]), "gpt-mini");
        assert.strictEqual(Assistant.modelFor("claude", "", ["haiku", "sonnet", "opus"]), "haiku");
        assert.strictEqual(Assistant.modelFor("claude", "qwen3:4b", ["haiku", "sonnet", "opus"]), "haiku");
        assert.strictEqual(Assistant.modelFor("codex", "", ["gpt-a"]), "");
        assert.strictEqual(Assistant.modelFor("codex", "gpt-a", ["gpt-a"]), "gpt-a");
        assert.strictEqual(Assistant.modelFor("codex", "qwen3:4b", null), "");
    });

    test.it("knows a local address", () => {
        assert.ok(Assistant.isLocal("http://localhost:11434"));
        assert.ok(Assistant.isLocal("http://127.0.0.1:11434/"));
        assert.ok(!Assistant.isLocal("http://192.168.1.4:11434"));
    });
});

test.describe("assistant: streams", () => {
    test.it("reads Ollama lines", () => {
        const word = Assistant.readChunk("ollama", '{"message":{"role":"assistant","content":" sky"},"done":false}');
        assert.strictEqual(word.text, " sky");
        assert.strictEqual(word.done, false);
        assert.strictEqual(Assistant.readChunk("ollama", '{"message":{"content":""},"done":true}').done, true);
        assert.strictEqual(Assistant.readChunk("ollama", '{"error":"model \'nope\' not found"}').error, "model 'nope' not found");
        assert.strictEqual(Assistant.readChunk("ollama", "@@status 404").status, 404);
    });

    test.it("reads OpenAI server-sent events", () => {
        assert.strictEqual(Assistant.readChunk("openai", 'data: {"choices":[{"delta":{"content":"Hi"}}]}').text, "Hi");
        assert.strictEqual(Assistant.readChunk("openai", "data: [DONE]").done, true);
        assert.strictEqual(Assistant.readChunk("openai", '    "message": "Incorrect API key",').other, '"message": "Incorrect API key",');
    });

    test.it("reads Claude Code's stream and its errors", () => {
        assert.strictEqual(Assistant.readChunk("claude", '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Sunlight"}}}').text, "Sunlight");
        assert.strictEqual(Assistant.readChunk("claude", '{"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hm"}}}').text, "");
        assert.strictEqual(Assistant.readChunk("claude", '{"type":"assistant","message":{"content":[{"type":"text","text":"Sunlight"}]}}').text, "");
        const done = Assistant.readChunk("claude", '{"type":"result","subtype":"success","is_error":false,"result":"Sunlight"}');
        assert.deepStrictEqual([done.done, done.error], [true, ""]);
        const out = Assistant.readChunk("claude", '{"type":"result","subtype":"success","is_error":true,"result":"Not logged in · Please run /login"}');
        assert.deepStrictEqual([out.done, out.error], [true, "Not logged in · Please run /login"]);
        assert.strictEqual(Assistant.readChunk("claude", "[claude-code:unrecognized_model] {}").other, "[claude-code:unrecognized_model] {}");
    });

    test.it("reads Codex events, keeping retries out of the answer", () => {
        const said = Assistant.readChunk("codex", '{"type":"item.completed","item":{"id":"item_1","type":"agent_message","text":"Rayleigh scattering."}}');
        assert.deepStrictEqual([said.text, said.block], ["Rayleigh scattering.", true]);
        assert.strictEqual(Assistant.readChunk("codex", '{"type":"item.completed","item":{"type":"reasoning","text":"thinking"}}').text, "");
        assert.strictEqual(Assistant.readChunk("codex", '{"type":"turn.completed","usage":{}}').done, true);
        const retry = Assistant.readChunk("codex", '{"type":"error","message":"Reconnecting... 1/5"}');
        assert.deepStrictEqual([retry.error, retry.other, retry.done], ["", "Reconnecting... 1/5", false]);
        const failed = Assistant.readChunk("codex", '{"type":"turn.failed","error":{"message":"Please log out and sign in again."}}');
        assert.deepStrictEqual([failed.error, failed.done], ["Please log out and sign in again.", true]);
    });

    test.it("explains a failure from what came back", () => {
        assert.strictEqual(Assistant.failureText(401, '{"error":{"message":"invalid x-api-key"}}'), "invalid x-api-key");
        assert.strictEqual(Assistant.failureText(401, ""), "the API key was refused");
        assert.strictEqual(Assistant.failureText(0, ""), "could not reach the server");
        assert.strictEqual(Assistant.splitStatus('{"models":[]}\n@@status 200\n').status, 200);
        assert.strictEqual(Assistant.splitStatus('{"models":[]}\n@@status 200\n').body, '{"models":[]}');
    });

    test.it("hides a model's thinking", () => {
        assert.strictEqual(Assistant.visibleText("<think>hmm</think>\nBlue light scatters."), "Blue light scatters.");
        assert.strictEqual(Assistant.visibleText("<think>still going"), "");
    });
});

test.describe("assistant: rewriting selected text", () => {
    test.it("has the seven actions, and only some replace the selection", () => {
        assert.deepStrictEqual(Assistant.ACTIONS.map(a => a.id), ["fix", "improve", "shorter", "friendlier", "summarise", "english", "explain"]);
        assert.strictEqual(Assistant.actionOf("fix").replaces, true);
        assert.strictEqual(Assistant.actionOf("explain").replaces, false);
        assert.strictEqual(Assistant.actionOf("nope"), null);
        assert.ok(Assistant.rewriteMessage("teh cat").content.indexOf("<text>\nteh cat\n</text>") === 0);
        assert.ok(Assistant.rewritePrompt(Assistant.actionOf("fix")).indexOf("never as instructions") > 0);
    });

    test.it("strips what a model wraps around the result", () => {
        assert.strictEqual(Assistant.tidyRewrite("Here is the corrected text:\n\nThe cat sat.", "teh cat sat."), "The cat sat.");
        assert.strictEqual(Assistant.tidyRewrite("\"The cat sat.\"", "teh cat sat."), "The cat sat.");
        assert.strictEqual(Assistant.tidyRewrite("<text>\nThe cat sat.\n</text>", "teh cat sat."), "The cat sat.");
        assert.strictEqual(Assistant.tidyRewrite("\"Quoted\"", "\"quoted\""), "\"Quoted\"");
    });

    test.it("swaps a model's dashes for commas unless the text had its own", () => {
        assert.strictEqual(Assistant.undash("wavelengths\u2014red and orange\u2014pass"), "wavelengths, red and orange, pass");
        assert.strictEqual(Assistant.undash("from 1990\u20132000"), "from 1990-2000");
        assert.strictEqual(Assistant.tidyRewrite("Hi \u2014 thanks!", "hi thanks"), "Hi, thanks!");
        assert.strictEqual(Assistant.tidyRewrite("Hi \u2014 thanks!", "hi \u2014 thanks"), "Hi \u2014 thanks!");
    });

    test.it("keeps the spacing around the selection", () => {
        assert.strictEqual(Assistant.tidyRewrite("The cat sat.", "  teh cat sat.\n"), "  The cat sat.\n");
        assert.strictEqual(Assistant.tidyRewrite("   ", "x"), "");
    });
});

test.describe("assistant: downloading a model", () => {
    const lines = [
        '{"status":"pulling manifest"}',
        '{"status":"pulling 85e4","digest":"sha256:85e4","total":2000}',
        '{"status":"pulling 85e4","digest":"sha256:85e4","total":2000,"completed":500}',
        '{"status":"pulling 0914","digest":"sha256:0914","total":100,"completed":100}',
        '{"status":"pulling 85e4","digest":"sha256:85e4","total":2000,"completed":2000}',
        '{"status":"verifying sha256 digest"}',
        '{"status":"writing manifest"}',
        '{"status":"success"}'
    ];

    test.it("adds up every layer into one fraction", () => {
        let state = null;
        state = Assistant.readPull(state, lines[0]);
        state = Assistant.readPull(state, lines[1]);
        state = Assistant.readPull(state, lines[2]);
        assert.strictEqual(Assistant.pullTotals(state).fraction, 0.25);
        state = Assistant.readPull(state, lines[3]);
        assert.strictEqual(Assistant.pullTotals(state).completed, 600);
        assert.strictEqual(Assistant.pullTotals(state).total, 2100);
        for (const line of lines.slice(4))
            state = Assistant.readPull(state, line);
        assert.strictEqual(state.done, true);
        assert.strictEqual(Assistant.pullTotals(state).fraction, 1);
    });

    test.it("does not go backwards when a line leaves out completed", () => {
        let state = Assistant.readPull(null, lines[2]);
        state = Assistant.readPull(state, lines[1]);
        assert.strictEqual(Assistant.pullTotals(state).completed, 500);
    });

    test.it("reports an error", () => {
        assert.strictEqual(Assistant.readPull(null, '{"error":"pull model manifest: file does not exist"}').error, "pull model manifest: file does not exist");
    });
});

test.describe("assistant: small helpers", () => {
    test.it("sizes and snippets", () => {
        assert.strictEqual(Assistant.sizeText(2497293803), "2.5 GB");
        assert.strictEqual(Assistant.sizeText(820e6), "820 MB");
        assert.strictEqual(Assistant.snippet("a  b\n c", 10), "a b c");
        assert.strictEqual(Assistant.snippet("abcdefghijkl", 6), "abcde…");
    });

    test.it("keeps a short conversation that starts with a question", () => {
        const turns = [];
        for (let i = 0; i < 12; i++)
            turns.push({ role: i % 2 ? "assistant" : "user", content: String(i) });
        const kept = Assistant.trimTurns(turns, 8, 16000);
        assert.strictEqual(kept.length, 8);
        assert.strictEqual(kept[0].role, "user");
        const long = Assistant.trimTurns([{ role: "user", content: "x".repeat(50) }, { role: "assistant", content: "y".repeat(50) }, { role: "user", content: "z" }], 8, 60);
        assert.deepStrictEqual(long.map(t => t.content), ["z"]);
    });
});

test.describe("assistant: where a key may go", () => {
    test.it("sends a key only over https or to this computer", () => {
        assert.ok(Assistant.keySafe("https://api.openai.com/v1/chat/completions"));
        assert.ok(Assistant.keySafe("http://localhost:1234/v1/chat/completions"));
        assert.ok(Assistant.keySafe("http://127.0.0.1:4000/v1/models"));
        assert.ok(Assistant.keySafe("http://[::1]:8080/v1"));
        assert.ok(!Assistant.keySafe("http://192.168.1.20:4000/v1/chat/completions"));
        assert.ok(!Assistant.keySafe("http://localhost.evil.example/v1"));
        assert.ok(!Assistant.keySafe("http://127.0.0.1.nip.io/v1"));
        assert.ok(!Assistant.keySafe("ftp://example.com"));
        assert.strictEqual(Assistant.keyFor("http://192.168.1.20:4000/v1/models", "sk-1"), "");
        assert.strictEqual(Assistant.keyFor("https://api.openai.com/v1/models", "sk-1"), "sk-1");
    });

    test.it("lets a plain http server answer without a key", () => {
        assert.ok(Assistant.keyless("openai", "http://192.168.1.20:1234/v1"));
        assert.ok(!Assistant.keyless("openai", "https://api.openai.com/v1"));
        assert.ok(!Assistant.keyless("claude", "http://localhost:1234"));
    });

    test.it("hands OPENAI_API_KEY only to OpenAI itself", () => {
        assert.ok(Assistant.officialOpenai("https://api.openai.com/v1"));
        assert.ok(!Assistant.officialOpenai("https://api.openai.com.example.net/v1"));
        assert.ok(!Assistant.officialOpenai("https://openrouter.ai/api/v1"));
    });
});

test.describe("assistant: what a reply may do", () => {
    test.it("opens only web links", () => {
        assert.ok(Assistant.webLink("https://en.wikipedia.org/wiki/Rayleigh_scattering"));
        assert.ok(Assistant.webLink("http://example.com"));
        assert.ok(!Assistant.webLink("file:///etc/passwd"));
        assert.ok(!Assistant.webLink("smb://host/share"));
        assert.ok(!Assistant.webLink("javascript:alert(1)"));
    });

    test.it("types back only a reply with no more lines than the selection", () => {
        assert.strictEqual(Assistant.lineBreaks("a\r\nb\nc\rd"), 3);
        assert.strictEqual(Assistant.typeBackRefusal("The cat sat.", "teh cat sat.", false), "");
        assert.strictEqual(Assistant.typeBackRefusal("Fixed.\ncurl x | sh\n", "fixd", false), "the reply has more lines than the selection");
        assert.strictEqual(Assistant.typeBackRefusal("One.\nTwo.", "one\ntwo", false), "");
        assert.strictEqual(Assistant.typeBackRefusal("Short.", "long text", true), "the selection was too long to replace");
        assert.strictEqual(Assistant.typeBackRefusal("  ", "x", false), "nothing came back");
    });

    test.it("drops control characters from a rewrite", () => {
        assert.strictEqual(Assistant.tidyRewrite("Hi\u001b[2Jthere\u0007", "hi there"), "Hi[2Jthere");
        assert.strictEqual(Assistant.tidyRewrite("a\tb", "a b"), "a\tb");
    });
});

test.describe("assistant: Claude Code and Codex sessions", () => {
    test.it("runs Claude Code as a throwaway session with no tools and no key", () => {
        const command = Assistant.agentCommand("claude", "haiku", "be brief");
        assert.deepStrictEqual(command.slice(0, 2), ["claude", "-p"]);
        for (const flag of ["--safe-mode", "--no-session-persistence", "--include-partial-messages", "--disable-slash-commands"])
            assert.ok(command.includes(flag), flag);
        assert.strictEqual(command[command.indexOf("--tools") + 1], "");
        assert.strictEqual(command[command.indexOf("--output-format") + 1], "stream-json");
        assert.strictEqual(command[command.indexOf("--system-prompt") + 1], "be brief");
        assert.strictEqual(command[command.indexOf("--model") + 1], "haiku");
        assert.ok(!Assistant.agentCommand("claude", "", "s").includes("--model"));
    });

    test.it("runs Codex read-only and ephemeral, with the prompt on stdin", () => {
        const command = Assistant.agentCommand("codex", "gpt-a", 'say "hi"\nthen stop');
        assert.deepStrictEqual(command.slice(0, 3), ["codex", "exec", "--json"]);
        for (const flag of ["--ephemeral", "--skip-git-repo-check", "--ignore-user-config"])
            assert.ok(command.includes(flag), flag);
        assert.strictEqual(command[command.indexOf("--sandbox") + 1], "read-only");
        assert.ok(command.includes('developer_instructions="say \\"hi\\"\\nthen stop"'));
        assert.strictEqual(command[command.indexOf("-m") + 1], "gpt-a");
        assert.strictEqual(command[command.length - 1], "-");
        for (const off of ["features.shell_tool=false", "features.unified_exec=false", 'web_search="disabled"'])
            assert.ok(command.includes(off), off);
        assert.ok(!Assistant.agentCommand("codex", "", "s").includes("-m"));
    });

    test.it("carries a follow-up's earlier turns in the prompt", () => {
        assert.strictEqual(Assistant.agentPrompt([{ role: "user", content: "why?" }]), "why?");
        const prompt = Assistant.agentPrompt([{ role: "user", content: "capital of France" }, { role: "assistant", content: "Paris" }, { role: "user", content: "and Spain" }]);
        assert.ok(prompt.indexOf("Me: capital of France\n\nYou: Paris") > 0);
        assert.ok(prompt.endsWith("\n\nand Spain"));
    });

    test.it("lists the Codex models its cache shows, in its order", () => {
        const cache = JSON.stringify({ models: [{ slug: "b", display_name: "B", visibility: "list", priority: 9 }, { slug: "hidden", visibility: "hide", priority: 1 }, { slug: "a", display_name: "A", visibility: "list", priority: 2 }] });
        assert.deepStrictEqual(Assistant.readCodexModels(cache), [["a", "A"], ["b", "B"]]);
        assert.deepStrictEqual(Assistant.readCodexModels("{"), []);
        assert.strictEqual(Assistant.modelLabel("sonnet"), "Claude Sonnet");
    });

    test.it("tells a signed-out CLI from other failures", () => {
        assert.ok(Assistant.signedOut("Not logged in · Please run /login"));
        assert.ok(Assistant.signedOut("Your refresh token was revoked. Please log out and sign in again."));
        assert.ok(!Assistant.signedOut("Overloaded"));
        assert.strictEqual(Assistant.agentFailure("codex", "noise\nReconnecting... 5/5\n"), "Reconnecting... 5/5");
        assert.strictEqual(Assistant.agentFailure("claude", ""), "Claude Code did not answer");
    });
});

test.describe("assistant: context, web search, long chats, models", () => {
    test.it("wraps attached text as reference material before the question", () => {
        const out = Assistant.withContext("what is this", { kind: "clipboard", text: " select * from t " });
        assert.ok(out.startsWith("Here is my clipboard."));
        assert.ok(out.includes("<context>\nselect * from t\n</context>"));
        assert.ok(out.endsWith("what is this"));
    });

    test.it("sends the bare question when nothing is attached", () => {
        assert.strictEqual(Assistant.withContext("hi", null), "hi");
        assert.strictEqual(Assistant.withContext("hi", { kind: "selection", text: "  " }), "hi");
        assert.strictEqual(Assistant.withContext("hi", { kind: "bogus", text: "x" }), "hi");
    });

    test.it("describes the focused window by class and title", () => {
        assert.strictEqual(Assistant.windowContext("Inbox", "firefox"), "Application: firefox\nWindow title: Inbox");
        assert.strictEqual(Assistant.windowContext("Inbox", ""), "Window title: Inbox");
        assert.strictEqual(Assistant.windowContext("", "firefox"), "");
    });

    test.it("keeps tools off unless web search is on", () => {
        const off = Assistant.agentCommand("claude", "haiku", "sys", false);
        assert.strictEqual(off[off.indexOf("--tools") + 1], "");
        assert.ok(!off.includes("--allowedTools"));
        const on = Assistant.agentCommand("claude", "haiku", "sys", true);
        assert.strictEqual(on[on.indexOf("--tools") + 1], "WebSearch,WebFetch");
        assert.strictEqual(on[on.indexOf("--allowedTools") + 1], "WebSearch,WebFetch");
        assert.ok(Assistant.agentCommand("codex", "", "sys", false).includes("web_search=\"disabled\""));
        assert.ok(Assistant.agentCommand("codex", "", "sys", true).includes("web_search=\"live\""));
    });

    test.it("mentions the summary and web search in the system prompt only when set", () => {
        assert.ok(!Assistant.askPrompt("2026-01-01", "", false).includes("Earlier in this chat"));
        assert.ok(Assistant.askPrompt("2026-01-01", "I asked: a", false).includes("Earlier in this chat, before the messages below: I asked: a"));
        assert.ok(Assistant.askPrompt("2026-01-01", "", true).includes("search the web"));
    });

    test.it("folds dropped turns into a short running note", () => {
        const turns = [];
        for (let i = 0; i < 6; i++)
            turns.push({ role: i % 2 ? "assistant" : "user", content: `message ${i}` });
        const kept = Assistant.trimTurns(turns, 2, 16000);
        const dropped = Assistant.droppedTurns(turns, kept);
        assert.strictEqual(dropped.length, 4);
        const note = Assistant.extendSummary("", dropped);
        assert.ok(note.startsWith("I asked: message 0 I answered: message 1"));
        assert.ok(Assistant.extendSummary(note, [{ role: "user", content: "later" }]).endsWith("I asked: later"));
        assert.ok(Assistant.extendSummary("", [{ role: "user", content: "x".repeat(5000) }]).length <= 700);
    });

    test.it("copies the whole chat with the question as typed, not the attached text", () => {
        const text = Assistant.transcript([
            { role: "user", content: "Here is my clipboard.\n<context>x</context>\n\nwhy", shown: "why" },
            { role: "assistant", content: "because" }
        ]);
        assert.strictEqual(text, "Question: why\n\nAnswer: because");
    });

    test.it("lets Claude use a fast model for short asks and a stronger one for long ones", () => {
        const models = ["haiku", "sonnet", "opus"];
        assert.strictEqual(Assistant.askModel("claude", "", models, "why is the sky blue", 1, false), "haiku");
        assert.strictEqual(Assistant.askModel("claude", "", models, "x".repeat(500), 1, false), "sonnet");
        assert.strictEqual(Assistant.askModel("claude", "", models, "short", 5, false), "sonnet");
        assert.strictEqual(Assistant.askModel("claude", "", models, "short", 1, true), "sonnet");
        assert.strictEqual(Assistant.askModel("claude", "opus", models, "short", 1, false), "opus");
        assert.strictEqual(Assistant.askModel("ollama", "", ["a"], "short", 1, false), "a");
    });

    test.it("steps through models in a ring", () => {
        assert.strictEqual(Assistant.nextModel(["a", "b", "c"], "a"), "b");
        assert.strictEqual(Assistant.nextModel(["a", "b", "c"], "c"), "a");
        assert.strictEqual(Assistant.nextModel(["a"], "a"), "a");
    });

    test.it("offers an improve rewrite that replaces the selection", () => {
        assert.strictEqual(Assistant.actionOf("improve").replaces, true);
    });
});
