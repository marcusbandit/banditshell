# Issue tracker: local markdown now, GitHub when public

banditshell is a solo project today and will be public later, so it has two
surfaces and one rule for choosing between them.

**Public: no.** _(Flip to `yes` once the repo is public and people other than the
author file issues. The routing rule below reads this flag.)_

## Which surface

- **Default: local markdown.** While `Public: no`, every spec and ticket a skill
  produces lands under `.scratch/`. Nothing goes to GitHub unless asked.
- **GitHub, even while `Public: no`**, in three cases: the ticket already exists
  there (someone filed it, or the user names a number), the user says to file it
  on GitHub, or the work is a release-facing bug or feature that should be
  visible in the repo's history.
- **Once `Public: yes`**, that inverts: anything a user of the shell would care
  about (bugs, features, regressions) is created on GitHub, and `.scratch/`
  keeps only internal exploration: prototypes, research notes, wayfinder maps.

When a local ticket is promoted to GitHub, add a `GitHub: #<n>` line near the top
of the local file and keep the local file as the working notes. The GitHub issue
is then the source of truth for status.

Note: `.scratch/` is not in `.gitignore`, so anything written there is committed
and will be visible when the repo goes public. Decide about that before flipping
the flag.

## Local markdown conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at
  `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a
  single combined tickets file
- Triage state is a `Status:` line near the top of each issue file (see
  `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom under a `## Comments`
  heading

## GitHub conventions

Use the `gh` CLI; it infers `marcusbandit/banditshell` from the clone.

- **Create**: `gh issue create --title "..." --body "..."`, heredoc for multi-line bodies
- **Read**: `gh issue view <number> --comments`, fetching labels too
- **List**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`, with `--label` / `--state` filters
- **Comment**: `gh issue comment <number> --body "..."`
- **Label**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

### Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs
as feature requests; `/triage` reads this flag. Worth revisiting when
`Public: yes`.)_

When set to `yes`, PRs run through the same labels and states as issues, using
the `gh pr` equivalents: `gh pr view <n> --comments`, `gh pr diff <n>`,
`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`
keeping only `authorAssociation` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR` or
`NONE`, then `gh pr comment` / `gh pr edit --add-label` / `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be
either: resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Apply the routing rule above. In the default case, create a new file under
`.scratch/<feature-slug>/`, creating the directory if needed.

## When a skill says "fetch the relevant ticket"

A number (`#42`, `issue 42`) means GitHub: `gh issue view 42 --comments`. A path
means the local file. When the reference is ambiguous, check `.scratch/` first,
since that is where most tickets live today.

## Wayfinding operations

Used by `/wayfinder`. Wayfinder efforts are exploration, so they stay local
regardless of the `Public` flag. The **map** is a file with one **child** file
per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`,
  with the question in the body. A `Type:` line records the ticket type
  (`research`/`prototype`/`grilling`/`task`); a `Status:` line records
  `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked
  when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open,
  unblocked and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set
  `Status: resolved`, then append a context pointer (gist + link) to the map's
  Decisions-so-far in `map.md`.
