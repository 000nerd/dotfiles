# macOS preference policy

[Setup guide](../../../docs/setup.md#macos-preferences-and-app-store-apps) ·
[Testing guide](../../../docs/testing.md)

## Managed declarations

The `personal` registry applies verified non-default differences and explicitly
reviewed customizations. Captured reference matches and unknown/provisional
values remain unmanaged.

| File | Purpose |
| --- | --- |
| [registry.sh](registry.sh) | Compose the selected registry for list, audit, or apply |
| [lib.sh](lib.sh) | Typed preference declarations, command capture, and audit behavior |
| [capture-policy.json](capture-policy.json) | Allowlist for portable preference capture |
| [captured-personal.json](captured-personal.json) | Comparison evidence and classification |
| [captured-personal.sh](captured-personal.sh) | Generated verified non-default declarations |
| [personal-overrides.sh](personal-overrides.sh) | Reviewed personal customizations |
| [common.sh](common.sh), [work.sh](work.sh) | Separate common/work declarations |
| [toggles.sh](toggles.sh) | Named reversible preference toggles |
| [retired.sh](retired.sh) | Inactive legacy declarations, not sourced by the registry |

The personal overrides include Dock auto-hide, title-bar double-click Fill,
margin-free tiling, Finder path bar, icon view, and new Finder windows at Desktop.
The `personal` profile is not layered on `common`/`work`. List the actual managed
settings with the command below rather than treating captured values as policy.

## Inspect, audit, apply

```sh
./bin/dotfiles macos list --profile personal
./bin/dotfiles macos audit --profile personal
./bin/dotfiles macos run --profile personal
./bin/dotfiles macos list --profile work
./bin/dotfiles macos toggle hidden-files on
./bin/dotfiles macos toggle desktop-icons off
```

Run examples from the repository root. List/audit are read-only; audit returns
nonzero for missing or drifted values. `run` also executes machine naming, power,
security, and other setup in [../defaults.sh](../defaults.sh). Inspect that script
before applying it to an existing Mac. Some changes require restarting an
application or signing out.

## Capture and compare

```sh
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
mkdir -p "$STATE_DIR/baselines"
python3 scripts/preferences.py capture --output "$STATE_DIR/baselines/current-ui-preferences.json"
bash tests/smoke/capture-reference.sh
python3 scripts/preferences.py build "$STATE_DIR/baselines/current-ui-preferences.json" \
  "$CACHE_DIR/defaults-reference/reference.json" \
  --output "$STATE_DIR/proposed-personal.json" --shell-output "$STATE_DIR/proposed-personal.sh"
```

Capture allowlists portable preference keys, normalizes home paths, and excludes
histories, accounts, device IDs, window geometry, Dock application lists, opaque
values, and unknown keys. The reference-capture command creates/reuses a real
Tart VM and writes output beneath the external cache directory;
`DOTFILES_REFERENCE_OUTPUT` overrides its output path.

A missing key does not establish an application's effective default. Comparison
distinguishes equal, different, and unavailable reference values. Generation
only applies captured differences when the reference has the same macOS version
and explicitly declares `factory_defaults_verified: true`. The provisioned Tart
reference does not assert that property, so its differences remain candidates
for review.

Review proposed JSON/shell output before changing the checked-in declarations.
Generated shell values are quoted as data. Intentional overrides belong in
`personal-overrides.sh`; matching defaults and unverified values remain unmanaged.
Removing a declaration does not remove a preference from an existing Mac.

After changing policy, run `bash scripts/check.sh`, then validate clean-install
and post-reboot behavior in a fresh macOS VM. Registry audit alone does not prove
that every application's live behavior matches its stored preferences.
