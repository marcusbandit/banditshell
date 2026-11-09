# Plugins hear when the launcher opens and closes

Status: ready-for-agent
GitHub: #808

A plugin is never told the launcher closed. Plugins that keep rows live with
`update` messages (Voice polls what is playing every second) have to guess;
Voice keeps updating for 60 seconds after the last query, which wastes work
when you close at once and goes stale if you leave it open.

Done when: the shell sends `{"type":"open"}` and `{"type":"close"}` to a
running plugin, documented in `docs/plugins/README.md`.
