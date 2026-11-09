# Commands take typed arguments in plain search

Status: resolved
PR: #821
GitHub: #807

A plugin command cannot ask for a value inline. The query is free text
(`services/plugin-protocol.js`), and the nearest thing, a form page, opens
only after Enter.

Use case: `dim spotify 15` and Enter sets Spotify to dim to 15% while you
dictate, with no page in between.

Done when: a manifest command can declare named arguments (text or choice,
optional or required), the search field shows them as fields after the
command word with Tab between them, and `activate` carries their values.
