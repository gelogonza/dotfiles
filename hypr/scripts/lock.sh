#!/usr/bin/env bash
# The one entry point for locking this session.
#
# Four things used to invoke a lock independently — the SUPER+L bind, the power
# menu, hypridle's idle timeout and its before-sleep hook — which meant
# "which lock do I actually get" had four answers and changing it meant
# changing four files. Everything routes through here now.
#
# Preference is the Quickshell lock (the one with the wave field). It lives
# inside the shell, which is the catch: if the shell is not running, or has been
# restarted mid-session, there is nothing to lock with. hyprlock is a standalone
# binary with no such dependency, so it is the fallback — and the fallback has
# to be real, because the failure mode of "lock did not happen" is an unlocked
# machine rather than an ugly one.
#
# Usage: lock.sh   (any arguments are passed to hyprlock if it is used)

set -uo pipefail

# Already locked by hyprlock — don't stack a second locker on top.
if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

# Does the shell expose the call?
#
# `ipc call` exits 0 for a function that does not exist — verified: a bogus
# function name and a bogus target both return 0, and only an unreachable
# instance returns non-zero. So reachability alone cannot be trusted here; if
# the handler were ever renamed, the call would quietly do nothing and the
# machine would stay unlocked. Check the surface first.
if quickshell -c gelo ipc show 2>/dev/null | awk '
        /^target lock$/   { in_lock = 1; next }
        /^target /        { in_lock = 0 }
        in_lock && /function lock\(\)/ { found = 1 }
        END               { exit !found }
    '; then
    if quickshell -c gelo ipc call lock lock >/dev/null 2>&1; then
        exit 0
    fi
fi

# No shell, no handler, or the call failed: lock anyway.
exec hyprlock "$@"
