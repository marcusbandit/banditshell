const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Assistant = lib("services/assistant.js", ["askOf", "looksLikeQuestion", "chatRequest", "listRequest", "pullRequest", "readModels", "readChunk", "splitStatus", "failureText", "visibleText", "tidyRewrite", "readPull", "pullTotals", "sizeText", "snippet", "trimTurns", "undash", "modelFor", "isLocal", "actionOf", "ACTIONS", "STARTER", "rewriteMessage", "rewritePrompt"]);

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
        const anthropic = Assistant.chatRequest("anthropic", settings, "s", messages);
        assert.strictEqual(anthropic.url, "https://api.anthropic.com/v1/messages");
        assert.strictEqual(anthropic.auth, "x-api-key: ");
        assert.ok(anthropic.headers.includes("anthropic-version: 2023-06-01"));
        const body = JSON.parse(anthropic.body);
        assert.strictEqual(body.system, "s");
        assert.deepStrictEqual(body.messages, messages);
        assert.ok(body.max_tokens > 0);
    });

    test.it("lists models where each backend keeps them", () => {
        assert.strictEqual(Assistant.listRequest("ollama", settings).url, "http://localhost:11434/api/tags");
        assert.strictEqual(Assistant.listRequest("openai", settings).url, "https://api.example.com/v1/models");
        assert.ok(Assistant.listRequest("anthropic", settings).url.indexOf("https://api.anthropic.com/v1/models") === 0);
        assert.strictEqual(JSON.parse(Assistant.pullRequest(settings, "x").body).model, "x");
    });

    test.it("reads model lists", () => {
        assert.deepStrictEqual(Assistant.readModels("ollama", '{"models":[{"name":"a:1"},{"model":"b"}]}'), ["a:1", "b"]);
        assert.deepStrictEqual(Assistant.readModels("anthropic", '{"data":[{"id":"claude-x"}]}'), ["claude-x"]);
        assert.strictEqual(Assistant.readModels("ollama", "<html>"), null);
    });

    test.it("picks a model that exists", () => {
        assert.strictEqual(Assistant.modelFor("ollama", "", ["x", Assistant.STARTER.name]), Assistant.STARTER.name);
        assert.strictEqual(Assistant.modelFor("ollama", "gone", ["x"]), "x");
        assert.strictEqual(Assistant.modelFor("ollama", "x", ["x", "y"]), "x");
        assert.strictEqual(Assistant.modelFor("ollama", "", []), "");
        assert.strictEqual(Assistant.modelFor("anthropic", "", []), "claude-haiku-5-5");
        assert.strictEqual(Assistant.modelFor("anthropic", "qwen", ["claude-a"]), "claude-a");
        assert.strictEqual(Assistant.modelFor("anthropic", "", ["claude-opus-9", "claude-haiku-9"]), "claude-haiku-9");
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

    test.it("reads Anthropic server-sent events", () => {
        assert.strictEqual(Assistant.readChunk("anthropic", "event: content_block_delta").other, "");
        assert.strictEqual(Assistant.readChunk("anthropic", 'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello"}}').text, "Hello");
        assert.strictEqual(Assistant.readChunk("anthropic", 'data: {"type":"message_stop"}').done, true);
        assert.strictEqual(Assistant.readChunk("anthropic", 'data: {"type":"error","error":{"type":"overloaded_error","message":"Overloaded"}}').error, "Overloaded");
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
    test.it("has the six actions, and only some replace the selection", () => {
        assert.deepStrictEqual(Assistant.ACTIONS.map(a => a.id), ["fix", "shorter", "friendlier", "summarise", "english", "explain"]);
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
