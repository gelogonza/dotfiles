#!/usr/bin/env bash
#
# git-context.sh <pid>
#
# Resolves the git repository that the focused window is "in" and prints it as
# JSON for the bar's git module. Prints {} when the window is not in a repo.
#
# The focused window's own cwd is usually not the interesting one: a terminal
# emulator typically sits in $HOME while the shell running inside it is in the
# project. So this walks the process tree from the window's pid downward and
# takes the deepest descendant whose cwd is inside a work tree — that is the
# thing the person is actually looking at.
#
# Output:
#   {"repo":"dotfiles-gelo","branch":"master","commit":"49a590b",
#    "subject":"Initial dotfiles commit","dirty":3}

set -uo pipefail

# With no argument, resolve the focused window ourselves. Quickshell's
# HyprlandToplevel carries the title from the event stream but only fills in
# lastIpcObject (which holds the pid) after an explicit refreshToplevels(),
# so asking the compositor directly is both simpler and always current.
pid="${1:-}"
if [[ -z "$pid" ]]; then
    pid=$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')
fi

[[ "$pid" =~ ^[0-9]+$ ]] || { echo '{}'; exit 0; }
# init is never a window's pid, and searching its subtree means searching every
# process on the machine — which will always find *some* repo.
(( pid > 1 )) || { echo '{}'; exit 0; }
[[ -d "/proc/$pid" ]] || { echo '{}'; exit 0; }

# --- level-order search: shallowest process whose cwd is in a work tree ----
#
# Level order, not deepest-first. The window process is checked before its
# children, its children before its grandchildren. That way a terminal sitting
# in $HOME falls through to the shell one level down that is cd'd into the
# project, while an unrelated deep descendant (a language server, a build tool
# that chdir'd elsewhere) can never outrank the shell the person is typing in.
#
# Depth is capped low for the same reason: past a few levels the processes have
# nothing to do with what the window is showing.
readonly MAX_DEPTH=4

repo_root=""
declare -a frontier=("$pid")

for ((depth = 0; depth <= MAX_DEPTH && ${#frontier[@]} > 0; depth++)); do
    for p in "${frontier[@]}"; do
        cwd=$(readlink -e "/proc/$p/cwd" 2>/dev/null) || continue
        [[ -z "$cwd" ]] && continue

        root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || continue
        repo_root="$root"
        break 2
    done

    mapfile -t frontier < <(pgrep -P "$(IFS=,; echo "${frontier[*]}")" 2>/dev/null)
done

[[ -z "$repo_root" ]] && { echo '{}'; exit 0; }

branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
# Detached HEAD reports "HEAD"; show the short sha instead so it is never blank.
[[ "$branch" == "HEAD" ]] && branch=$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null)

commit=$(git -C "$repo_root" log -1 --format=%h 2>/dev/null)
subject=$(git -C "$repo_root" log -1 --format=%s 2>/dev/null)
dirty=$(git -C "$repo_root" status --porcelain 2>/dev/null | wc -l)

# jq -R -s builds correctly escaped JSON strings; the subject line is arbitrary
# user text and absolutely will contain quotes eventually.
jq -n \
    --arg repo "$(basename "$repo_root")" \
    --arg branch "$branch" \
    --arg commit "$commit" \
    --arg subject "$subject" \
    --argjson dirty "${dirty:-0}" \
    '{repo:$repo, branch:$branch, commit:$commit, subject:$subject, dirty:$dirty}'
