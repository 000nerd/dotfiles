# Testing and verification

[Back to README](../README.md)

Run examples from the repository root. Local regression checks use disposable
homes/repositories and mocked system commands. Docker and Tart examples create
real containers or VMs and can run package installation inside them.

## Local checks and CI

```sh
bash scripts/check.sh
```

The runner checks Bash/Zsh syntax, compiles Python sources in memory, and runs
the Python and shell regression suites. It uses Python 3 and Bash; Zsh-specific
checks require Zsh. Native Codex integration cases require the Codex CLI and are
explicitly skipped when it is unavailable. No packages are installed and no host
preferences are applied by this suite.

[GitHub Actions](../.github/workflows/test.yml) runs the same command on Linux
and macOS, followed by an installer dry-run. This is a regression gate, not proof
that a full clean-machine install succeeds.

| Focused check | Coverage |
| --- | --- |
| `python3 tests/test_setup.py` | Install/restore, package helpers, source exports, inventories, Git/port helpers, and import safety |
| `python3 tests/test_editors.py` | Settings/extension policy, JSONC, backups, local overrides, and drift |
| `python3 tests/test_codex_theme.py` | Theme assets, font policy, private settings modes, and optional native config writes |
| `bash tests/test_dotfiles_help.sh` | Help and command routing without running action-only subcommands |
| `bash tests/test_macos_logic.sh` | Installer command capture in a temporary home |
| `bash tests/test_macos_defaults.sh` | Registry composition, audit behavior, toggles, and preference-write classification |
| `bash tests/test_theme_logic.sh` | Theme application to temporary settings and logged preset imports |

The Codex tests use a temporary `CODEX_HOME`; their native writer cases do not
modify the real user configuration. UI appearance, running language servers,
and physical-device behavior still require manual acceptance.

## Isolated symlink check

```sh
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-links.XXXXXX")
HOME="$TEST_HOME" ./install.sh --only symlinks --dry-run
HOME="$TEST_HOME" ./install.sh --only symlinks
```

Only the temporary home receives links. A full installer dry-run can be checked
separately with `./install.sh --profile personal --dry-run`.

## Observed baselines and declaration checks

```sh
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p "$STATE_DIR/baselines"
python3 scripts/setup-state.py capture --output "$STATE_DIR/baselines/current-mac.json"
python3 scripts/setup-state.py verify --profile personal
```

Capture records an observed inventory. Verify checks the machine against the
repository's declarations and reports missing or unverified items; it does not
repair them. Select a subset with `--steps`, and omit GUI cask/App Store checks
with `--skip-casks`.

```sh
python3 scripts/setup-state.py verify --steps symlinks
```

After making intended setup changes, capture again and compare the observations:

```sh
python3 scripts/setup-state.py capture --output "$STATE_DIR/baselines/after.json"
python3 scripts/setup-state.py compare "$STATE_DIR/baselines/current-mac.json" \
  "$STATE_DIR/baselines/after.json" --output "$STATE_DIR/baselines/comparison.json"
```

Comparison exit codes are `0` for matching inspected fields, `1` for differences,
and `2` for partial/unverified evidence. Package/app/extension versions are only
compared with `--exact-versions`; runtime versions and readable selected
preferences are always compared exactly. Verify uses `0` for passed, `1` for
failed declarations, and `2` for partial evidence.

Captures include package/tool versions, selected preferences, managed links,
application bundles, VS Code extension IDs/versions, and service context. They
omit credentials, SSH keys, histories, complete preference domains, and application
settings contents. Saved JSON reports use mode `0600`; review them before sharing.
A baseline is evidence, not an instruction to install every observed application.

## Linux container

With Docker available:

```sh
bash tests/docker/run.sh
```

This builds [tests/docker/Dockerfile](../tests/docker/Dockerfile) and opens an
interactive Zsh session in a disposable container. It does not run the installer
automatically. Inside the container, run the dry-run or the desired installation:

```sh
./install.sh --profile personal --dry-run
./install.sh --profile personal
```

This exercises Linux behavior only; macOS application/preferences acceptance
requires a Mac or macOS VM.

## macOS VM with Tart

The host runner requires Tart, sshpass, SSH, rsync, and Python 3 on a compatible
macOS host. Use its help for current flags and environment overrides:

```sh
bash tests/smoke/tart.sh --help
```

A bounded fresh-install run:

```sh
bash tests/smoke/tart.sh --vm dotfiles-baseline --fresh --source working \
  --profile personal --only symlinks,brew,macos --skip-casks --stop-after
```

`--fresh` deletes and recreates the named VM. Defaults are image
`ghcr.io/cirruslabs/macos-sequoia-base:latest`, user/password `admin`/`admin`,
100 GB guest disk, and a minimum 80 GiB of host free space before cloning.
`--skip-casks` skips the macOS cask/App Store block, not formula installation.

For a full install, allocate sufficient guest disk for applications and language
toolchains. This example also compares against a captured baseline:

```sh
BASELINE="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/baselines/current-mac.json"
bash tests/smoke/tart.sh --vm dotfiles-baseline --fresh --source working \
  --profile personal --disk-size 150 --baseline "$BASELINE" --stop-after
```

The host exports the selected source, runs the installer/verification in the
guest, and collects logs beneath
`${XDG_CACHE_HOME:-~/.cache}/dotfiles/tart-smoke/<vm>/`. Override the host output
with `DOTFILES_TART_LOG_DIR`.

| Source mode | Contents |
| --- | --- |
| `--source working` | Tracked working files plus nonignored new files, preserving working-tree deletions |
| `--source head` | Committed `HEAD` exported with `git archive` |

The guest receives a source snapshot without `.git/`. `source.json` records the
exported hashes/modes. Guest artifacts include `install-result.json` and, when a
baseline is supplied, `observed.json` and `comparison.json`. App Store status can
remain pending separately from core installation.

After rebooting an existing guest, verify persistence without reinstalling:

```sh
bash tests/smoke/tart.sh --vm dotfiles-baseline --source working --verify-only \
  --profile personal --disk-size 150 --baseline "$BASELINE" --stop-after
```

Match the source, profile, selected steps, and cask choices to the install run.
`--verify-only` requires an existing VM and cannot be combined with `--fresh` or
`--dry-run-install`. Passing VM checks still leaves physical-Mac acceptance for
trackpad, sleep/wake, displays, application appearance, permissions, account
sign-ins, and live editor/language-server behavior.

For macOS preference-reference capture and its evidence limits, see
[the preference policy](../install/macos/defaults/README.md#capture-and-compare).
