# macOS preference profiles

The personal profile manages only intentional non-default preferences.
`captured-personal.json` retains the comparison evidence for named portable
preferences; `captured-personal.sh` contains only verified non-default
declarations. Reference matches and unknown/provisional defaults are not
written. `personal-overrides.sh` applies separately reviewed customizations:
Dock auto-hide, title-bar double-click Fill, and no tiled-window margins.
The Finder walkthrough additionally selected path bar on, icon view, and new
windows opening at the user's Desktop. Filename extensions remain at the
macOS default without an explicit write.
Dock magnification, position, and minimize animation are left to macOS.

`common.sh` and `work.sh` retain the separate legacy common/work profile.
They are not automatically layered onto the captured personal profile.

## Capture and compare

```bash
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
mkdir -p "$STATE_DIR/baselines"
python3 scripts/preferences.py capture --output "$STATE_DIR/baselines/current-ui-preferences.json"
bash tests/smoke/capture-reference.sh
python3 scripts/preferences.py build "$STATE_DIR/baselines/current-ui-preferences.json" \
  "$CACHE_DIR/defaults-reference/reference.json" \
  --output "$STATE_DIR/proposed-personal.json" --shell-output "$STATE_DIR/proposed-personal.sh"
```

Capture exports selected domains in memory, persists only allowlisted portable
keys, normalizes home paths, and excludes histories, accounts, device IDs,
window geometry, Dock application lists, opaque values, and unknown keys.
Generated shell values are quoted as data; they are never evaluated as code.
Review the proposed files before copying them into this directory.

A missing key in `defaults` does not reveal an application's effective default.
The comparison distinguishes equal, different, and unavailable reference
values. Different macOS versions are provisional, and Tart vanilla images
include provisioning tweaks. An initialized reference desktop is recorded in
the evidence. Do not describe unavailable reference values as confirmed
non-default settings. Generation requires a same-version reference explicitly
marked `factory_defaults_verified: true` before applying captured differences.
The provisioned Tart reference does not meet that requirement, so its differences
remain review candidates. Capture evidence alone never pins matching defaults.
Reviewed intentional changes belong in the explicit overrides; existing default
values do not. Removing a declaration does not delete preferences from an
existing Mac; clean-install behavior must be checked in a fresh VM.

## Inspect, audit, apply

```bash
bin/dotfiles macos list --profile personal
bin/dotfiles macos audit --profile personal
bin/dotfiles macos run --profile personal
```

List/audit are read-only. Run also executes the machine setup in
`install/macos/defaults.sh`, including naming, power and security settings; inspect
that script before applying it to an existing Mac. The preference registry
itself applies only the selected typed declarations. Some GUI changes require
restarting an application or signing out. Native Fill uses the available
desktop area; it does not force every app into a separate full-screen Space.

All intentional preference writes belong here or in `toggles.sh`. Add policy
keys deliberately and rerun the safe test suite plus live VM and post-restart
checks when regenerating a profile.
