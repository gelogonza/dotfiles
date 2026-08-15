# Spotify — spicetify theme, rollback, recovery

Read this before running any spicetify command.

**spicetify is not like the rest of this repo.** Every other target is a config
file that an app reads. spicetify *modifies the Spotify installation in place* —
it unpacks `/opt/spotify/Apps/xpui.spa` into a directory, rewrites the
JavaScript and CSS inside it, and leaves it that way. There is no "off" switch
in a config file. Getting back to stock means restoring from a backup, and if
that backup is wrong you reinstall the package.

That is the whole reason this document exists.

---

## The state on this machine

| | |
|---|---|
| Spotify | `/opt/spotify`, pacman package `spotify` (AUR) |
| spicetify | 2.44.0, `/usr/bin/spicetify` |
| config | `~/.config/spicetify/config-xpui.ini` |
| themes | `~/.config/spicetify/Themes/` |
| **backup** | `~/.local/state/spicetify/Backup/` — `xpui.spa`, `login.spa` |

`/opt/spotify` is mode `777`. spicetify needs to write there as your user, and
this is the standard spicetify setup step — but it does mean any local user can
modify your Spotify client. That is a real trade, made knowingly.

Our theme is `spicetify/gelo-xmb/` in this repo, symlinked in as
`~/.config/spicetify/Themes/gelo-xmb`, so regenerating updates it in place.

---

## Check the backup before you touch anything

```bash
grep -A3 '^\[Backup\]' ~/.config/spicetify/config-xpui.ini
pacman -Q spotify
```

The `version` under `[Backup]` must match the installed Spotify version. If it
does not, **the backup is stale and `spicetify restore` cannot return you to
stock** — go to *Recovery* below instead.

Verify the backup is not truncated:

```bash
python3 -c "import zipfile,os;p=os.path.expanduser('~/.local/state/spicetify/Backup/xpui.spa');z=zipfile.ZipFile(p);print(len(z.namelist()),'entries, corrupt:',z.testzip())"
```

544 entries and `corrupt: None` is healthy.

---

## ⚠️ The one command that destroys your way back

**Never run `spicetify backup` while Spotify is already patched.** It backs up
whatever is in `/opt/spotify` *right now* — which, if already patched, means
your backup becomes a copy of the modified client and stock Spotify is
unrecoverable except by reinstalling.

`spicetify backup apply` is the same trap with an extra step on the end. It is
the correct command **only on a fresh, unpatched Spotify install** — i.e. right
after installing Spotify or upgrading the package.

To re-apply to an already-patched install, the command is plain:

```bash
spicetify apply
```

If you are not sure which state you are in: a patched install has a
`/opt/spotify/Apps/xpui/` **directory**; an unpatched one has only
`xpui.spa` files.

---

## Applying our theme

```bash
design/build-tokens.py
ln -sfn ~/dotfiles/spicetify/gelo-xmb ~/.config/spicetify/Themes/gelo-xmb
spicetify config current_theme gelo-xmb color_scheme base
spicetify apply
```

`spicetify apply` closes and relaunches Spotify. Anything playing stops.

Changing a colour afterwards is `design/build-tokens.py && spicetify apply`.

---

## Rollback to the previous theme

Nothing about the Spotify install needs to change — only which theme is
selected:

```bash
spicetify config current_theme StarryNight color_scheme orange
spicetify apply
```

## Rollback to stock Spotify (no spicetify at all)

```bash
spicetify restore
```

This puts back `xpui.spa` and `login.spa` from the backup and deletes the
unpacked directory. It also removes the **Marketplace** custom app, which is
installed here — re-add it with `spicetify config custom_apps marketplace` and
re-apply if you want it back.

---

## Recovery — Spotify is broken, or the backup is stale

Reinstall the package. This replaces `/opt/spotify` wholesale and is the
guaranteed way back:

```bash
sudo pacman -S spotify
sudo chmod -R a+wr /opt/spotify        # spicetify needs write access again
spicetify backup apply                  # correct HERE: the install is fresh
```

If you want stock Spotify and no spicetify, stop after the reinstall.

---

## After a Spotify upgrade

A `pacman -Syu` that upgrades `spotify` replaces `/opt/spotify` and **silently
wipes the patch** — Spotify comes back stock and unthemed, and the old backup
now refers to a version that no longer exists.

That is the one moment `backup apply` is correct, because the install is
genuinely fresh:

```bash
sudo chmod -R a+wr /opt/spotify
spicetify backup apply
```

Symptom that you have hit this: Spotify looks stock after an update, and
`spicetify apply` either errors about a version mismatch or appears to work
while changing nothing.

---

## The three files, and which one is load-bearing

`spicetify/gelo-xmb/` contains a `color.ini`, a `user.css` and a `theme.js`.
**When something breaks, delete from the bottom of this list upward** and
re-apply after each step — the first one that fixes it names the culprit.

| File | Is | Delete it and you get |
|---|---|---|
| `color.ini` | the theme | nothing works |
| `user.css` | the material — chrome, glow, hairlines | a flat but correct theme |
| `theme.js` | the motion — wave field, beat ripples, control panel | the static material theme |

## Tuning it live

Profile menu → **XMB field**, or **Ctrl+Alt+X**. Settings persist per machine in
Spotify's LocalStorage; **Reset** returns to the generated defaults exactly.

| Control | Default | Does |
|---|---|---|
| Colour source | tokens.json | `tokens.json` / Custom (picker + hex) / Album art |
| Surface style | Tinted | Tinted (chrome takes the colour) / Neutral black |

In **Custom** and **Album art** modes the buttons, hex input, sliders and
waveform go white — a tinted control on a tinted surface is two things
competing for one hue. `tokens.json` mode is unchanged.
| Detected | — | the colour read off the current cover, live |
| Field | on | the wave field itself |
| Cool lock | on | compresses any hue toward the palette's 207.5°, ±25° |
| Turntable | on | right-panel cover art as a spinning record |
| Waveform bar | on | the playback bar drawn as the track's loudness envelope |
| Tint strength | 0.65 | how far toward the chosen colour source |
| Field brightness | 1.00 | filament intensity |
| Field saturation | 1.00 | |
| Main view scrim | 0.68 | extra hold-back for home content, multiplied by UI opacity |
| UI opacity | 1.00 | **master** — left panel, top bar, home, player bar, cards, right panel |
| Right panel | 0.88 | now-playing panel, multiplied by UI opacity |
| Beat reactivity | 1.00 | how hard a beat surges the band drift, and the confidence floor for a beat |
| Drift rate | 1.00 | 0 freezes the field; ripples still fire |
| Spin period | 14s | one revolution |

**Colour changes can never affect contrast.** Hue and saturation move; the WCAG
relative luminance of every field colour is solved back to its original value.
That is why an album tint cannot undo the measured contrast in design.md §8d —
see `docs/CHANGES.md` for why holding HSL *lightness* is not sufficient (a 1.70×
luminance swing).

`tokens.json` is still the source of truth. The panel is for *finding* a value
on the live thing — **Copy** puts the current settings on the clipboard so a
number you like can be moved back into the token source. A value that only
lives in the panel is a value that does not survive a new machine.

Not Ctrl+Shift+X — that is Spotify's Connect panel, and binding it opens both.

**The `color.ini` is the theme.** It feeds only spicetify's `--spice-*` custom
properties, which is the narrowest and most stable part of the contract. 17 of
its 19 keys are live in Spotify 1.2.95.

**`theme.js` is the most optional and the most likely to break.** It runs the
XMB wave field behind the app on WebGL2 and ripples it on the beat, and it
injects its own transparency/scrim CSS — so removing the file removes the hole
and the thing filling it together. Nothing in `user.css` depends on it.

**`user.css` is optional too.** It adds the material language — the brushed
gradient on the player bar, the bloom on the transport, rows and cards. If a
Spotify update breaks either:

```bash
rm ~/dotfiles/spicetify/gelo-xmb/theme.js   # motion first
spicetify apply
rm ~/dotfiles/spicetify/gelo-xmb/user.css   # then material
spicetify apply
```

`design/build-tokens.py` regenerates whichever you removed.

What remains is still a complete, correct theme. That is the point of keeping
them separate — **when something breaks, delete the stylesheet first and see if
you still care.**

Three rules keep the stylesheet cheap to lose:

1. Colour comes from `var(--spice-*)`, never a literal, so it inherits the
   palette automatically.
2. Visual properties only — background, box-shadow, border, filter. Nothing
   that participates in layout, so a stale selector costs an effect rather
   than a broken window.
3. Selectors are `data-testid` or Spotify's own semantic class names
   (`.x-progressBar-fillColor`, `.main-trackList-*`). **Never a hashed
   styled-components class** like `.eWU4JoxyECcwnSf_` — those change between
   builds.

### Surfaces that stay stock, deliberately

- A ~58px `#c0d62f` ring on the account avatar. Not routed through `--spice-*`.
- **The play button is white, and that is correct.** It is an Encore control
  with `colorSet="invertedLight"`, and spicetify's `replace_colors` already
  rewires that colour set to our palette — it follows `--spice-text`. The
  circle itself is painted by a hashed class, so neither
  `background-color: !important` nor overriding Encore's colour-set variables
  reaches it. It is lit with a bloom instead of repainted.

If you are theming any other Encore control: **set the colour set, do not fight
the paint.** The sets are defined in `xpui-snapshot.css`:

```bash
grep -o '\.encore-inverted-light-set[^{]*{[^}]*}' /opt/spotify/Apps/xpui/xpui-snapshot.css
```

---

## Symptom → cause

| Symptom | Cause | Fix |
|---|---|---|
| `spicetify apply` does nothing | Spotify was upgraded; install is stock again | `spicetify backup apply` (see above) |
| Colours unchanged after apply | `replace_colors = 0` | `spicetify config replace_colors 1` |
| Spotify won't start after apply | bad patch | `spicetify restore`, then reinstall if that fails |
| "backup version mismatch" | stale backup | reinstall the package, then `backup apply` |
| Permission denied writing to /opt | package upgrade reset the mode | `sudo chmod -R a+wr /opt/spotify` |
| Theme dir not found | symlink missing | re-run the `ln -sfn` above |
| Green accents still showing | surface not routed through `--spice-*` | expected — see above |
| Play button is white | Encore `invertedLight`, follows `--spice-text` | expected, not a bug |
| An effect vanished after an update | a `user.css` selector went stale | delete `user.css`, re-apply; colours still work |
| Layout broken after an update | should not happen — `user.css` sets no layout | delete `user.css`, re-apply, and file what changed |
| Background is flat, no field | WebGL2 unavailable, or shader failed to compile | `theme.js` removes itself cleanly on failure; check the Spotify console |
| Field visible but nothing propagates | ripple clock — see docs/CHANGES.md | `rippleSpeed` must be divided by the time scale |
| Text harder to read over the field | scrim too light for your display | raise **Scrim** in the panel, then move it into `render_spicetify_js()` |
| Warm/coloured wash over the main view | Spotify's album-art tint showing through a translucent surface | the `--background-tinted-*` and action-bar-gradient overrides handle it; if a new surface leaks, neutralise the same way |
| Panel won't open | `Spicetify.Menu` unavailable | Ctrl+Alt+X still works — it is registered independently |
| Progress bar looks normal, no waveform | that track has no audio analysis | expected — local files and most podcasts have none |
| A surface stays solid at low UI opacity | a class between `:root` and the element re-declares the variable | check which ancestor declares it closest — usually `.encore-dark-theme`; override there, not at `:root` |
| Field follows the album but the UI does not | a `:root` override losing to `colors.css`, which loads later | use `html:root` — specificity (0,1,1) beats (0,1,0) regardless of order |
| One box keeps the old colour | spicetify exposes each surface twice — a colour *and* an `--spice-rgb-*` triplet | override both; `--spice-main` and the triplets are easy to miss |
| A region retints on hover | Spotify sets `--background-image` **inline** per item | already neutralised with `--background-image: none !important` — inline beats a plain declaration |
