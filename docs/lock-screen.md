# Lock screen — test procedure and recovery

There are two locks installed.

| Key | Lock | Status |
|---|---|---|
| `SUPER + L` | hyprlock | the fallback, unchanged |
| `SUPER + SHIFT + L` | Quickshell lock | **untested — read this first** |

The Quickshell lock (`quickshell/gelo/Lock/`) is a real ext-session-lock client
with the XMB shader background, matching the login screen and the wallpaper.
hyprlock cannot do this — it has no shader hook at all; its background is an
image or a blurred screenshot.

---

## Why this needs a deliberate first test

`WlSessionLock` is a real lock: **the compositor keeps the session locked even
if the client dies.** That is exactly what you want from a lock and exactly what
makes an untested one dangerous. If the shell crashes while locked, there is no
UI left to type into.

What has been verified:

- The QML loads with no errors and the surface renders on every screen.
- PAM starts a transaction against `/etc/pam.d/hyprlock`, prompts for a
  password, and **rejects a wrong one** (`PamResult.Failed`) — it fails closed.
- The appearance is correct (checked via preview, which engages no lock).

What has **not** been verified, because it needs your actual password:

- That a *correct* password unlocks.

That is the one step you have to do.

---

## Testing it

1. **Open a rescue TTY first — `Ctrl+Alt+F3`.** Log in and leave it logged in.
   Return to the desktop with `Ctrl+Alt+F2`.

   > **Not F2.** This graphical session *runs on VT2*
   > (`loginctl show-session $XDG_SESSION_ID -p VTNr`), so `Ctrl+Alt+F2` takes
   > you straight back to the locked screen rather than to a shell. This file
   > said F2 for a long time, which would have been discovered at the exact
   > moment it mattered. VTs 1 and 3–6 are free, and logind spawns a getty on
   > switch (`NAutoVTs=6`), so F3 gives a login prompt on demand.
2. **Rehearse with a grace period.** `--grace N` accepts *any* keypress for the
   first N seconds without a password, so you can confirm the lock draws,
   accepts input and dismisses — without your password being the only way out:

   ```bash
   hyprlock --grace 30
   ```

   If it renders and a keypress dismisses it, the config parses, the fonts
   resolve and the compositor hands over the session correctly. Only
   authentication is left unproven.

3. Check the Quickshell lock's appearance without locking anything:

   ```bash
   qs -c gelo ipc call lock preview      # toggles; click or call again to dismiss
   ```

4. Lock for real:

   ```bash
   qs -c gelo ipc call lock lock         # or SUPER+SHIFT+L
   ```

5. Type a **wrong** password first. Expect a shake, a ripple through the field,
   and "Incorrect password".
6. Type your real password. Expect it to unlock.

Note that step 5 costs one `faillock` attempt. The default policy is `deny=3`
with `unlock_time=600`, so entries expire on their own; `faillock --user $USER`
shows the current count.

---

## If you get stuck

1. `Ctrl+Alt+F3` for a TTY, log in. (**Not F2** — that is this session's own
   VT; see the note above.)
2. Unlock the graphical session:

   ```bash
   loginctl list-sessions
   loginctl unlock-session <id>
   ```

3. If that does not work, kill the lock client — the compositor drops the lock
   when told the session is unlocked, or you can end the session outright:

   ```bash
   pkill -x quickshell          # the lock goes with it; compositor may hold the lock
   loginctl terminate-session <id>
   ```

4. Back in a working session, revert to hyprlock only by removing the
   `SUPER SHIFT, L` line from `hypr/hyprland.conf`.

---

## Promoting it

Once it has let you back in at least twice, swap the two lines in
`hypr/hyprland.conf`:

```
bind = SUPER, L, exec, quickshell -c gelo ipc call lock lock
bind = SUPER SHIFT, L, exec, hyprlock
```

Keep hyprlock bound to something. It is the only lock that survives the shell
being restarted, which happens every time you edit the shell.

---

## Design notes

**No `unlock` IPC verb, deliberately.** Anything that releases the lock without
going through PAM would make the lock bypassable by any process running as you,
which would defeat the point. The only way out is the password.

**PAM config is `/etc/pam.d/hyprlock`** (`auth include login`). That file ships
with the hyprlock package, so uninstalling hyprlock could remove it and leave
this lock unable to start a transaction — the screen would say "PAM failed to
start — use a TTY". A dedicated config is more robust:

```bash
printf '#%%PAM-1.0\nauth include login\n' | sudo tee /etc/pam.d/gelo-lock
```

then set `config: "gelo-lock"` in `quickshell/gelo/Lock/Lock.qml`.

**The password** is held in one property, handed to `PamContext` when PAM asks
for it, and cleared on every terminal outcome. It is never logged, never written
to disk, and never interpolated into a shell command.

**Restarting the shell while locked** kills the lock UI. The compositor keeps
the session locked, so recover via TTY as above. This is the main practical
hazard of using a shell-hosted lock, and the reason hyprlock stays bound.

---

## Pre-flight audit (2026-08-15)

Everything checkable without locking the session was checked. Findings:

| Check | Result |
|---|---|
| `/etc/pam.d/hyprlock` | present, `auth include login` |
| `pam_unix.so` / `pam_faillock.so` / `pam_systemd.so` | all resolve |
| hyprlock | v0.9.6 |
| Geist (`$font_display`) | 10 faces installed, `fc-match` resolves |
| hypridle | running, locks at 300s via `loginctl lock-session` |
| Every `$var` in `hyprlock.conf` | resolves against `tokens.conf` — **after two fixes** |
| Rescue VT | **was documented wrong** — see above |

Three defects found and fixed, none of which would have shown up until the
moment the lock mattered:

1. **`rounding = $glass_radius` — undefined.** The variable died with the
   glass → chrome rename and nothing referenced it afterwards, so it sat in the
   lock config as a silent no-op. Now `$chrome_radius`.
2. **`inner_color = rgba(16181dae)` — a hardcoded near-black** left over from
   the dark palette, on a system where every other surface comes from the token
   source and the palette has since been inverted. Now `rgba(f8fbffe6)`, light
   surface with navy ink, matching every other input.
3. **`fail_color = $glow`** — the accent at 20% alpha, over a blurred and
   dimmed screenshot. As the *only* signal that a password was rejected that is
   close to invisible. Now `$accent_rgba`: same hue family as `check_color`,
   separated by intensity rather than by a new colour, which is how this system
   builds hierarchy everywhere else.

**Still unverified, and only you can do it:** that a correct password unlocks.
Rehearse with `hyprlock --grace 30` first — that proves everything except
authentication, without your password being the only way out.
