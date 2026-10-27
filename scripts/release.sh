#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "usage: release.sh [--dry-run] [--skip-boot-check] [--repo <dir>]"
    echo "  cut the next release from origin/main: check it, pick the number from"
    echo "  the commit types since the last tag, tag it, push the tag and move"
    echo "  stable in one atomic push, then write the GitHub release from the"
    echo "  what's-new entries since the last tag. --dry-run does every check and"
    echo "  prints what it would do, and pushes nothing. Without gamescope the boot"
    echo "  check cannot run, and it refuses unless --skip-boot-check is given"
    exit "${1:-2}"
}

repo="" dry=0 skip_boot=0
while [ $# -gt 0 ]; do
    case "$1" in
    --dry-run) dry=1 ;;
    --skip-boot-check) skip_boot=1 ;;
    --repo)
        [ $# -ge 2 ] || usage
        repo="$2"
        shift ;;
    -h | --help) usage 0 ;;
    *) usage ;;
    esac
    shift
done

[ -n "$repo" ] || repo="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."
repo="$(git -C "$repo" rev-parse --show-toplevel)"
cd "$repo"
remote=origin
export GIT_TERMINAL_PROMPT=0 LC_ALL=C

red=$'\033[31m' green=$'\033[32m' dim=$'\033[2m' plain=$'\033[0m'
[ -t 1 ] || { red="" green="" dim="" plain=""; }

stop() {
    echo "${red}not released: $1${plain}" >&2
    exit 1
}

show() { printf '%q ' "$@" | sed 's/ $//'; echo; }

said() { grep -m1 -E '^[A-Za-z]*Error:' <<<"$1" || tail -n 1 <<<"$1"; }

command -v node >/dev/null || stop "node is not installed"
gh_ready=1
if ! command -v gh >/dev/null; then
    gh_ready=0 gh_why="gh is not installed, so the GitHub release cannot be written"
elif ! gh auth status >/dev/null 2>&1; then
    gh_ready=0 gh_why="gh is not logged in, so the GitHub release cannot be written; run gh auth login"
fi
[ "$gh_ready" = 1 ] || [ "$dry" = 1 ] || stop "$gh_why"
git remote get-url "$remote" >/dev/null 2>&1 || stop "this copy has no remote called $remote"

git fetch --quiet --no-tags "$remote" "+refs/heads/main:refs/remotes/$remote/main" "+refs/tags/v*:refs/tags/v*" 2>/dev/null ||
    stop "could not fetch main and the tags from $remote"
if git ls-remote --exit-code --heads "$remote" stable >/dev/null 2>&1; then
    git fetch --quiet --no-tags "$remote" "+refs/heads/stable:refs/remotes/$remote/stable" 2>/dev/null || stop "could not fetch stable from $remote"
else
    git update-ref -d "refs/remotes/$remote/stable"
fi

[ -z "$(git status --porcelain)" ] || stop "this copy has edits or untracked files; release from a clean checkout of $remote/main"
main_sha="$(git rev-parse "refs/remotes/$remote/main")"
head_sha="$(git rev-parse HEAD)"
[ "$head_sha" = "$main_sha" ] || stop "this copy is at ${head_sha:0:7}, not $remote/main (${main_sha:0:7}); check out $remote/main first"

helper="$repo/services/whatsnew.js"
last="$(git tag --merged "$main_sha" -l 'v*' | node "$helper" newest 2>&1)" || stop "could not read the release tags: $(said "$last")"
if [ -n "$last" ]; then
    subjects="$(git log --format=%s "$last..$main_sha")"
else
    subjects="$(git log --format=%s "$main_sha")"
fi
since="${last:-the start}"
next="$(node "$helper" next "$last" <<<"$subjects" 2>&1)" && status=0 || status=$?
case "$status" in
0) read -r tag bump <<<"$next" ;;
3) stop "main has nothing new since $since" ;;
*) stop "could not work out the next number from the commits since $since: $(said "$next")" ;;
esac

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null || git ls-remote --exit-code --tags "$remote" "refs/tags/$tag" >/dev/null 2>&1; then
    stop "the tag $tag exists already, but not on main"
fi
stable_sha="$(git rev-parse -q --verify "refs/remotes/$remote/stable" || true)"
if [ -n "$stable_sha" ]; then
    git merge-base --is-ancestor "$stable_sha" "$main_sha" || stop "stable (${stable_sha:0:7}) is not behind main, so moving it would rewrite what people have"
fi

tree="$(mktemp -d)"
trap 'rm -rf "$tree" "$tree".*' EXIT
git archive "$main_sha" | tar -x -C "$tree"
notes="$tree.notes.md"
if [ -n "$last" ]; then
    git show "$last:docs/whats-new.json" >"$tree.before.json" 2>/dev/null || : >"$tree.before.json"
    node "$helper" notes "$tree.before.json" "$tree/docs/whats-new.json" >"$notes"
else
    node "$helper" notes /dev/null /dev/null --first >"$notes"
fi

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
if [ "$skip_boot" = 1 ]; then
    echo "${dim}skip boot check: --skip-boot-check${plain}"
elif command -v gamescope >/dev/null && [ -x "$tree/cli/banditshell" ]; then
    check "boot check" env -u BANDITSHELL_DIR "$tree/cli/banditshell" dev check boot "$tree.boot"
else
    if command -v gamescope >/dev/null; then why="main has no cli/banditshell to boot"; else why="it needs gamescope, which is not installed"; fi
    echo "${red}FAIL${plain} boot check: $why; --skip-boot-check releases without it" >&2
    failed+=("boot check")
fi

[ "${#failed[@]}" -eq 0 ] || stop "${failed[*]} did not pass on main (${main_sha:0:7})"

count="$(grep -c . <<<"$subjects" || true)"
case "$bump" in
first) echo "main ${main_sha:0:7} becomes $tag, the first release" ;;
minor) echo "main ${main_sha:0:7} becomes $tag: $count commits since $last, with a feature or a breaking change" ;;
major) echo "main ${main_sha:0:7} becomes $tag: $count commits since $last, with a breaking change" ;;
*) echo "main ${main_sha:0:7} becomes $tag: $count commits since $last, fixes only" ;;
esac
echo "${dim}release notes:${plain}"
sed 's/^/  /' "$notes"

tag_command=(git tag -a "$tag" "$main_sha" -m "banditshell $tag")
push_command=(git push --atomic "$remote" "refs/tags/$tag" "$main_sha:refs/heads/stable")
release_command=(gh release create "$tag" --verify-tag --title "banditshell $tag" --notes-file "$notes")

if [ "$dry" = 1 ]; then
    echo "to release, it would run:"
    for command in tag_command push_command release_command; do
        declare -n words="$command"
        echo -n "  "; show "${words[@]}"
        unset -n words
    done
    [ "$gh_ready" = 1 ] || echo "${red}a real run would refuse: $gh_why${plain}"
    echo "${dim}dry run: nothing was tagged or pushed${plain}"
    exit 0
fi

show "${tag_command[@]}"
"${tag_command[@]}"
show "${push_command[@]}"
if ! "${push_command[@]}"; then
    git tag -d "$tag" >/dev/null
    stop "the push was refused, so neither the tag nor stable moved"
fi
show "${release_command[@]}"
if ! "${release_command[@]}"; then
    kept="$(git rev-parse --absolute-git-dir)/release-notes-$tag.md"
    cp "$notes" "$kept"
    echo "${red}$tag is out and stable moved, but the GitHub release was not written; finish it with:${plain}" >&2
    show gh release create "$tag" --verify-tag --title "banditshell $tag" --notes-file "$kept" >&2
    exit 1
fi
echo "${green}released $tag${plain}"
