# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those
roles to the actual label strings used in this repo's issue tracker. banditshell
uses the canonical names unchanged.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the
corresponding label string from this table.

## How the label is carried

- **GitHub**: a real label. `gh issue edit <n> --add-label "ready-for-agent"`.
  The labels do not exist in `marcusbandit/banditshell` yet; create one the first
  time it is needed with
  `gh label create ready-for-agent --description "Fully specified, ready for an AFK agent"`.
- **Local markdown**: the same string on the `Status:` line near the top of the
  issue file, e.g. `Status: ready-for-agent`. One role at a time.

Edit the right-hand column to match whatever vocabulary you actually use.
