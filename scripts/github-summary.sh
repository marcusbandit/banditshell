#!/usr/bin/env bash
set -u

command -v gh >/dev/null 2>&1 || exit 3
gh auth token >/dev/null 2>&1 || exit 4

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

gh repo list --limit 100 --json nameWithOwner,description,url,isPrivate,isFork,pushedAt >"$work/repos" 2>/dev/null &
gh search prs --author @me --state open --limit 30 --json number,title,repository,url,updatedAt,isDraft >"$work/pulls" 2>/dev/null &
gh search issues --assignee @me --state open --limit 30 --json number,title,repository,url,updatedAt >"$work/issues" 2>/dev/null &
gh api 'notifications?per_page=50' --jq length >"$work/notifications" 2>/dev/null &
wait

part() {
    if [ -s "$work/$1" ]; then
        cat "$work/$1"
    else
        printf '%s' "$2"
    fi
}

[ -s "$work/repos" ] || exit 1
printf '{"repos":%s,"pulls":%s,"issues":%s,"notifications":%s}\n' "$(part repos '[]')" "$(part pulls '[]')" "$(part issues '[]')" "$(part notifications -1)"
