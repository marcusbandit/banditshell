#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: promote-stable.sh [--repo <dir>] [--remote <name>] [--no-fetch] [--push]"
    echo "  check that main is fit to become the stable channel, then print the"
    echo "  commands that would move it. It never pushes unless --push is given."
    echo "  checks, run on a clean export of main: the node tests, check-modules,"
    echo "  lint-rules, qml-compile-check, a what's-new id on the newest entry,"
    echo "  and that main is on GitHub and only moves stable forward"
    exit "${1:-2}"
}

repo="" remote=origin fetch=1 push=0
while [ $# -gt 0 ]; do
    case "$1" in
    --push) push=1 ;;
    --no-fetch) fetch=0 ;;
    --repo)
        [ $# -ge 2 ] || usage
        repo="$2"
        shift ;;
    --remote)
        [ $# -ge 2 ] || usage
        remote="$2"
        shift ;;
    -h | --help) usage 0 ;;
    *) usage ;;
    esac
    shift
done

if [ -z "$repo" ]; then
    repo="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
fi
repo="$(git -C "$repo" rev-parse --show-toplevel)"
cd "$repo"

red=$'\033[31m' green=$'\033[32m' dim=$'\033[2m' plain=$'\033[0m'
[ -t 1 ] || { red="" green="" dim="" plain=""; }

stop() {
    echo "${red}not promoted: $1${plain}" >&2
    exit 1
}

[[ $remote != -* ]] || stop "$remote is not a remote name"
git remote get-url "$remote" >/dev/null 2>&1 || stop "this copy has no remote called $remote"
git rev-parse -q --verify refs/heads/main >/dev/null || stop "there is no local main branch"

if [ "$fetch" = 1 ]; then
    GIT_TERMINAL_PROMPT=0 git fetch --quiet "$remote" "+refs/heads/main:refs/remotes/$remote/main" 2>/dev/null || stop "could not fetch main from $remote"
    if GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code --heads "$remote" stable >/dev/null 2>&1; then
        GIT_TERMINAL_PROMPT=0 git fetch --quiet "$remote" "+refs/heads/stable:refs/remotes/$remote/stable" 2>/dev/null || stop "could not fetch stable from $remote"
    else
        git update-ref -d "refs/remotes/$remote/stable"
    fi
fi

main_sha="$(git rev-parse refs/heads/main)"
remote_main="$(git rev-parse -q --verify "refs/remotes/$remote/main" || true)"
[ -n "$remote_main" ] || stop "$remote has no main branch in this copy; fetch first"
[ "$main_sha" = "$remote_main" ] || stop "local main (${main_sha:0:7}) is not the same as $remote/main (${remote_main:0:7}); stable can only get what is already on GitHub, so push or pull main first"

stable_sha="$(git rev-parse -q --verify "refs/remotes/$remote/stable" || true)"
if [ -n "$stable_sha" ]; then
    [ "$stable_sha" != "$main_sha" ] || stop "stable is already at ${main_sha:0:7}, nothing to promote"
    git merge-base --is-ancestor "$stable_sha" "$main_sha" || stop "stable (${stable_sha:0:7}) is not an ancestor of main, so stable would move sideways or back"
fi

command -v node >/dev/null || stop "node is not installed"

tree="$(mktemp -d)"
trap 'rm -rf "$tree"' EXIT
git archive "$main_sha" | tar -x -C "$tree"

version="$(cd "$tree" && node -e '
const fs = require("node:fs");
let doc;
try { doc = JSON.parse(fs.readFileSync("docs/whats-new.json", "utf8")); } catch (e) { process.exit(3); }
const list = Array.isArray(doc) ? doc : Array.isArray(doc.entries) ? doc.entries : [];
const newest = list.find(e => e && !e.example);
if (!newest) process.exit(4);
const id = typeof newest.id === "string" ? newest.id.trim() : "";
if (!/^[0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]+)?$/.test(id)) process.exit(5);
process.stdout.write(id);
')" || case $? in
    3) stop "docs/whats-new.json on main is missing or not valid JSON" ;;
    4) stop "docs/whats-new.json on main has no entry" ;;
    *) stop "the newest entry in docs/whats-new.json has no id like 2026-10-17 or 2026-10-17-2" ;;
esac
tag="v$(sed -e 's/-/./' -e 's/-/./' <<<"$version")"

failed=()
check() {
    local name="$1" log
    shift
    log="$tree.$name.log"
    if (cd "$tree" && "$@") >"$log" 2>&1; then
        echo "${green}ok${plain}   $name"
    else
        echo "${red}FAIL${plain} $name" >&2
        tail -n 12 "$log" | sed 's/^/     /' >&2
        failed+=("$name")
    fi
    rm -f "$log"
}

compgen -G "$tree/tests/*.test.js" >/dev/null || stop "main has no tests"

check "node tests" bash -c 'node --test tests/*.test.js'
check "check-modules" node scripts/check-modules.js
check "lint-rules" node scripts/lint-rules.js
check "qml-compile-check" bash scripts/qml-compile-check.sh "$tree"

[ "${#failed[@]}" -eq 0 ] || stop "${failed[*]} did not pass on main (${main_sha:0:7})"

count="$(git rev-list --count "${stable_sha:-$main_sha}..$main_sha" 2>/dev/null || echo 0)"
[ -n "$stable_sha" ] || count="all of main"
echo "${dim}main ${main_sha:0:7} is version $version, ahead of stable by $count${plain}"

push_command=(git push "$remote" main:stable)
tag_command=(git tag -a "$tag" "$main_sha" -m "banditshell $version")
tag_push_command=(git push "$remote" "$tag")
tag_known=0
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || git ls-remote --exit-code --tags "$remote" "refs/tags/$tag" >/dev/null 2>&1; then
    tag_known=1
fi

show() { printf '%q ' "$@" | sed 's/ $//'; echo; }

if [ "$push" = 0 ]; then
    echo "to promote, run:"
    echo -n "  "; show "${push_command[@]}"
    if [ "$tag_known" = 0 ]; then
        echo -n "  "; show "${tag_command[@]}"
        echo -n "  "; show "${tag_push_command[@]}"
    else
        echo "${dim}the tag $tag exists already, so no tag is made${plain}"
    fi
    echo "${dim}nothing was pushed${plain}"
    exit 0
fi

show "${push_command[@]}"
"${push_command[@]}"
if [ "$tag_known" = 0 ]; then
    show "${tag_command[@]}"
    "${tag_command[@]}"
    show "${tag_push_command[@]}"
    "${tag_push_command[@]}"
fi
