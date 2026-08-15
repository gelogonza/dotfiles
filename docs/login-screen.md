# Login screen — install, rollback, recovery

The login screen is an SDDM theme (`sddm/themes/gelo-liquid`) with a real GLSL
shader background. This is the one surface in the system that gets a shader: it
is the first thing seen, it is looked at while idle, and unlike the lock screen
it is not on the critical path back into a running session.

**Your machine currently boots to GDM.** GDM cannot run a custom QML theme, so
using this theme means switching display managers. That is a change with a real
failure mode, so read this whole file before running anything.

---

## 1. Install the theme (safe — changes nothing about boot)

```bash
sudo sddm/install.sh
```

This copies the theme to `/usr/share/sddm/themes/gelo-liquid` and writes
`/etc/sddm.conf.d/10-gelo.conf`. It does **not** enable SDDM. GDM stays your
display manager until you explicitly switch.

The theme is copied rather than symlinked on purpose: the greeter runs as the
unix user `sddm`, and `/home/gelo` is mode `700`. A symlink into your home
directory produces a greeter that cannot read its own theme — which shows up as
a blank or fallback login screen. **Re-run `sudo sddm/install.sh` after any
change to the theme**, or you will be looking at a stale copy.

## 2. Verify it renders

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/gelo-liquid
```

You should get the fluid shader background, the clock in Inter, and the glass
password field. In test mode the username is blank (there is no real session)
and login always fails — that is expected, and it is a good way to see the
failure animation. Close it with `pkill -x sddm-greeter-qt6`.

If you get a blank screen or the default theme instead, check permissions:

```bash
sudo ls -la /usr/share/sddm/themes/gelo-liquid
```

Everything must be world-readable.

## 3. Switch the display manager

Only after step 2 looks right:

```bash
sudo systemctl disable gdm.service
sudo systemctl enable sddm.service
```

Reboot.

> Do not run `systemctl stop gdm` while logged in — that kills your running
> session immediately. Switch, then reboot.

---

## Recovery — if the graphical login does not come back

This is the failure this whole procedure is designed around. It is recoverable
and nothing is lost; you just need a text console.

1. At the black/blank screen press **Ctrl + Alt + F2**. That switches to a
   TTY — a plain text login. (F3, F4… also work if F2 is occupied.)
2. Log in with your normal username and password.
3. Put GDM back:

   ```bash
   sudo systemctl disable sddm.service
   sudo systemctl enable gdm.service
   sudo reboot
   ```

You are now exactly where you started.

To find out what went wrong before reverting:

```bash
journalctl -b -u sddm --no-pager | tail -50
```

The usual causes, in order of likelihood:

| Symptom | Cause | Fix |
|---|---|---|
| Blank screen, greeter respawning | theme unreadable by user `sddm` | `sudo chmod -R a+rX /usr/share/sddm/themes/gelo-liquid` |
| Default theme instead of this one | `Current=` not applied | check `/etc/sddm.conf.d/10-gelo.conf` exists |
| Login screen but no background | `.qsb` shader missing from the copy | `design/build-shaders.sh` then re-run the installer |
| Cursor only, nothing draws | Qt cannot pick a render backend | try `DisplayServer=x11` in the conf, or set `QT_QUICK_BACKEND=software` in `GreeterEnvironment` |

---

## Rollback (complete)

```bash
sudo systemctl disable sddm.service
sudo systemctl enable gdm.service
sudo rm -rf /usr/share/sddm/themes/gelo-liquid
sudo rm -f /etc/sddm.conf.d/10-gelo.conf
sudo reboot
```

---

## Editing the theme

Colours, spacing, type and motion all come from `design/tokens.json`. After
changing tokens:

```bash
design/build-tokens.py      # regenerates Theme/Tokens.qml in the theme
sudo sddm/install.sh        # copies the updated theme into /usr/share
```

After changing `Shaders/fluid.frag`:

```bash
design/build-shaders.sh     # Qt 6 will not accept raw GLSL — it needs .qsb
sudo sddm/install.sh
```

### A note on the shader's speed

The field animates at `time * 0.28`. That looks high for an "ambient" effect and
it is deliberate. At the original `0.06`, measurement showed **zero changed
pixels over 30 seconds** — on a palette this dark (`bg-0`…`border` spans only
13–42 in 8-bit) the motion quantised away entirely and the shader rendered a
still image. The palette also gained `--border` as a fourth tonal stop for the
same reason: to give the field enough range to be visibly in motion. At the
current setting roughly 90% of pixels change over 4 seconds.
