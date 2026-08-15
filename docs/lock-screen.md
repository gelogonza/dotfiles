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

1. **Open a TTY first.** `Ctrl+Alt+F2`, log in, and leave it logged in. Return
   with `Ctrl+Alt+F1`. If anything goes wrong, that session is your way back.
2. Check the appearance without locking anything:

   ```bash
   qs -c gelo ipc call lock preview      # toggles; click or call again to dismiss
   ```

3. Lock for real:

   ```bash
   qs -c gelo ipc call lock lock         # or SUPER+SHIFT+L
   ```

4. Type a **wrong** password first. Expect a shake, a ripple through the field,
   and "Incorrect password".
5. Type your real password. Expect it to unlock.

Note that step 4 costs one `faillock` attempt. The default policy is `deny=3`
with `unlock_time=600`, so entries expire on their own; `faillock --user $USER`
shows the current count.

---

## If you get stuck

1. `Ctrl+Alt+F2` for a TTY, log in.
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
