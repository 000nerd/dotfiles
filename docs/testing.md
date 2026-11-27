# Testing Dotfiles

This project includes several ways to test the installation scripts in clean environments.

## 1. GitHub Actions (Automated)

The project is configured with GitHub Actions to test the installation on every push and pull request.
It runs on:
- `ubuntu-latest`
- `macos-latest`

*Note: CI focuses on syntax, dry-run, and symlink logic. Full package installation is better exercised manually because it is slow and mutates the host runner.*

## 2. Local Linux Testing (Docker)

You can test the Linux installation using the provided Docker setup:

```bash
./tests/docker/run.sh
```

Inside the container, run:
```bash
./install.sh
```

## 3. Local macOS Testing (Virtualization)

Since macOS cannot be run in Docker, you should use a Virtual Machine for a clean test.

### Option A: Tart (CLI-based, Recommended for Apple Silicon)

[Tart](https://github.com/cirruslabs/tart) is a lightweight virtualization tool for macOS on Apple Silicon.

The repository includes a host-side runner and a guest-side smoke script:

```bash
brew install cirruslabs/cli/tart cirruslabs/cli/sshpass
./tests/smoke/tart.sh --fresh --profile personal --only symlinks,brew,macos --skip-casks
```

The runner clones a Tart macOS image, starts the VM, waits for SSH, copies the current checkout into `~/.dotfiles` inside the guest, and runs `tests/smoke/macos-guest.sh`. Logs are copied back under `${XDG_CACHE_HOME:-~/.cache}/dotfiles/tart-smoke/<vm-name>/guest`.

Useful variants:

```bash
./tests/smoke/tart.sh --profile personal
./tests/smoke/tart.sh --profile personal --dry-run-install
./tests/smoke/tart.sh --fresh --profile personal --skip-casks
./tests/smoke/tart.sh --fresh --profile personal --skip java --skip-casks
./tests/smoke/tart.sh --fresh --profile personal --skip java,python --skip-casks
./tests/smoke/tart.sh --fresh --profile personal --only symlinks,brew,macos --skip-casks
./tests/smoke/tart.sh --fresh --profile personal --disk-size 100
./tests/smoke/tart.sh --fresh --profile personal --stop-after
DOTFILES_TART_IMAGE=ghcr.io/cirruslabs/macos-tahoe-base:latest ./tests/smoke/tart.sh --fresh
```

The bounded VM smoke command focuses on the bootstrap spine: symlinks, Homebrew formula availability, and macOS defaults. The full personal profile can exhaust a 100 GB guest disk while unpacking current Node/npm globals, JDK/Gradle dependencies, Python tool wheels, and large GUI apps. Use the full personal command when you can allocate a larger guest disk:

```bash
./tests/smoke/tart.sh --fresh --profile personal --disk-size 150
```

Defaults:

- VM name: `dotfiles-smoke`
- Image: `ghcr.io/cirruslabs/macos-sequoia-base:latest`
- Guest credentials: `admin` / `admin`
- Install profile: `personal`
- Required free space before clone: 80 GiB, configurable with `DOTFILES_TART_MIN_FREE_GB`
- Guest disk size: 100 GB, configurable with `--disk-size` or `DOTFILES_TART_DISK_SIZE_GB`
- Install step filtering: pass through with `--only step[,step]` and `--skip step[,step]`
- GUI cask installs: enabled by default, disabled with `--skip-casks`

Manual Tart flow:

1.  **Install Tart:**
    ```bash
    brew install cirruslabs/cli/tart
    ```
2.  **Pull a clean macOS image:**
    ```bash
    tart pull ghcr.io/cirruslabs/macos-sonoma-base:latest
    ```
3.  **Clone the image for testing:**
    ```bash
    tart clone ghcr.io/cirruslabs/macos-sonoma-base:latest test-vm
    ```
4.  **Run the VM:**
    ```bash
    tart run test-vm
    ```
5.  **Inside the VM**, clone your dotfiles and run `./install.sh`.

### Option B: UTM (GUI-based)

[UTM](https://getutm.app/) is a great GUI for managing VMs on macOS.

1.  Download and install UTM.
2.  Download a macOS IPSW (from within UTM or Apple).
3.  Create a new Virtual Machine and install macOS.
4.  **Important:** Take a "Snapshot" of the fresh installation before running your dotfiles, so you can easily revert and test again.

## 4. Manual Logic Check (Custom HOME)

To test symlinking logic without affecting your real system files:

```bash
mkdir -p /tmp/dotfiles-test
HOME=/tmp/dotfiles-test ./install.sh --dry-run --only symlinks
```

To actually create links in the temporary home:

```bash
HOME=/tmp/dotfiles-test ./install.sh --only symlinks
```

To check a full personal run without changing anything:

```bash
./install.sh --profile personal --dry-run
```

## 5. Safe macOS Logic Test

To test the macOS path without a clean macOS instance and without mutating your current machine:

```bash
./tests/test_macos_logic.sh
```

This runs the installer against a temporary `HOME`, forces the installer down the macOS branch, and captures intended macOS commands to a `macos-commands.log` under a unique temporary test directory (printed by the test) instead of executing them.

It also verifies that the number of emitted writes exactly matches the selected
personal defaults registry.

## 6. macOS Defaults Registry Test

To verify classification, profile composition, audit coverage, and reversible
toggles without changing the current Mac:

```bash
./tests/test_macos_defaults.sh
```

This confirms that personal contains all common and personal declarations,
work excludes personal-only declarations, audit visits the complete registry,
and no active raw `defaults write` exists outside `install/macos/defaults`.

## 7. Dotfiles Command Help Test

To verify that bare `dotfiles` subcommands show help instead of running mutating actions:

```bash
./tests/test_dotfiles_help.sh
```

This checks `dotfiles`, each action subcommand such as `dotfiles macos`, and passthrough commands such as `dotfiles install --dry-run` and `dotfiles theme list`.

## 8. Safe Theme Logic Test

To test theme switching without touching real app settings:

```bash
./tests/test_theme_logic.sh
```

This creates fake VS Code and Obsidian config locations under a unique temporary directory, captures iTerm/Terminal imports to a log, and verifies the supported theme profiles update their targets as expected.

Run `python3 tests/test_codex_theme.py` for the current Codex settings adapter.
It covers policy-derived fonts, dry-run without a CLI or writes, missing CLI
errors, and preventing a success marker after a write failure. When `codex` (or
`DOTFILES_CODEX_CLI`) is installed, it also exercises the actual native config
writer in a temporary `CODEX_HOME`: all three themes, preservation of comments,
unrelated settings and UI/prose fonts, selected-face removal, backups, no-op
reapplication, and rejection of concurrent semantic config changes. Native
integration cases are explicitly skipped when the CLI is unavailable. No real
Codex config or global-state file is modified by these tests.

## 9. Regression suite and observed machine baseline

Run all safe checks with one command:

```bash
bash scripts/check.sh
```

The regression suite uses temporary homes, fake update commands, and disposable
Git repositories. It covers nested restore preservation, broken links, paths
with spaces, repeat installs, update failures, Node selection, Python tool
failures, source exports, and baseline comparison. CI runs this command on
Linux and macOS. It does not install packages or apply host preferences.

The shared package declarations live in `install/packages.sh`; both installers
and complete inventory verification use those declarations. Node defaults to
the latest LTS and Java to 21. Override `DOTFILES_NODE_VERSIONS` (space separated),
`DOTFILES_NODE_DEFAULT`, and `DOTFILES_JAVA_DEFAULT` for another supported setup.
The update command installs/updates the latest LTS runtime and its npm; it propagates
failures and loads nvm in its own Bash process.

Capture the current machine without applying installer settings:

```bash
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
mkdir -p "$STATE_DIR/baselines"
python3 scripts/setup-state.py capture --output "$STATE_DIR/baselines/current-mac.json"
python3 scripts/setup-state.py verify > "$STATE_DIR/baselines/current-declaration-check.log"
```

The second command can fail: that means the current machine differs from the
installer's declarations. It does not repair the machine. Captures include
package versions, Node/npm/Python/uv/Java versions, npm and uv tool inventories,
selected preference keys, managed-link state, top-level application bundle
versions, VS Code extension identifiers/versions, and observed Homebrew service
status. Baselines are written with mode 0600 under the external state directory in
these examples. Keep them local unless you have reviewed them for sharing.

No credentials, SSH keys, histories, shell environment dumps, browser profiles,
complete preference domains, or application settings files are copied. The
baseline is an observation, not an instruction to reinstall every listed tool
or to reproduce missing/broken settings. Compare it with the intended package
and preference declarations before promoting any differences into policy.
Unavailable inventory sections and unreadable/missing preference keys are
reported as unverified, never as a match. A stale Homebrew cask receipt can make
its version unavailable even when its name is visible. uv may need permission
to acquire an inventory lock in its cache; grant that access when capturing
from a restricted execution environment.

A first VM test can use a bounded installation:

```bash
./tests/smoke/tart.sh --vm dotfiles-baseline --fresh --source working \
  --profile personal --only symlinks,brew,macos --skip-casks --stop-after
```

For the full installation and observed-baseline comparison:

```bash
./tests/smoke/tart.sh --vm dotfiles-baseline --fresh --source working \
  --profile personal --disk-size 150 \
  --baseline "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/baselines/current-mac.json" --stop-after
```

The default `working` export includes tracked working files plus new nonignored
files. It excludes ignored local leftovers. Deleted
working files remain deleted. `--source head` tests the committed source with
`git archive`; commit the new harness before using that lane. Neither export
requires staging changes. Logs include `source.json` with the exact tested file
hashes and modes. Source export and all fast tests also work without a `.git`
directory in the guest.

The guest runs the selected installation twice and checks every declared
formula, cask (unless skipped), npm global, uv tool, managed symlink, and selected
macOS defaults. It checks Node/npm, Java/javac/jenv, and Python/uv in a login
shell. If a baseline is supplied, it also writes `observed.json` and
`comparison.json` to the collected guest logs. Differences make the comparison
fail; unknown evidence makes it partial. This is expected while the installer
and your observed baseline intentionally differ.

Comparison exit codes: 0 = matched inspected fields, 1 = differences, 2 = partial
because some fields could not be verified. Package/app/extension comparisons
check presence by default. Add `--exact-versions` to include their versions;
runtime versions and readable selected preferences are always compared exactly.
Home paths and checkout paths are normalized. SMB machine identity is excluded
from comparison because the guest intentionally has a different name. Service
status and OS version are included as context, not enforced across machines.

After rebooting the guest, check persistence without reinstalling:

```bash
./tests/smoke/tart.sh --vm dotfiles-baseline --source working --verify-only \
  --profile personal --baseline "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/baselines/current-mac.json" --stop-after
```

Use the same source, profile, step filters, and cask selection as the original
run. `--verify-only` requires an existing VM and cannot be combined with
`--fresh`. A successful VM run still needs physical-Mac checks for trackpad,
sleep/wake, displays, GUI themes, permissions, account sign-ins, and shell plugin
readiness. The headless shell reports missing plugins without prompting.

### Live VM fixes

Homebrew disabled `dupeguru` on 2026-09-01 for failing Gatekeeper checks; it is
excluded from automatic installation. `handbrake-app` and `memory-meter-3`
replace their renamed cask tokens. The discontinued PyCharm CE cask is replaced by the maintained `pycharm` cask.
IntelliJ is excluded; Android Studio remains selected.
The captured host baseline retains its original names as historical evidence.

Shell plugin registration explicitly detaches stdin to avoid zplug's deprecated
pipe syntax when running under SSH. The Homebrew loader is separate from the
user-writable `~/.zplug` state directory. Installation provisions configured
plugins and the guest verifies `zplug check`; a missing plugin cache is never
silently treated as a complete shell setup. `ZPLUG_HOME` can still be overridden.

VLC has a narrowly scoped official-mirror fallback when its redirect host is
unavailable. It queries the original Homebrew cask metadata, downloads only
from VideoLAN's official HTTPS mirror, verifies the original SHA-256, and
populates Homebrew's cache. Homebrew then performs normal cask installation.
No quarantine/signature bypass flags are used.

`python` and `python3` both use Homebrew Python 3 in login and interactive
shells. The unversioned executables are added through Homebrew's `libexec/bin`;
active virtual environments retain precedence. Node installation
uses `nvm install --lts` by default, and update also refreshes the `lts/*`
default alias.

Guest logs include `install-result.json` (installation, repeat install, declared
inventory, baseline comparison, operational notices) and
`post-reboot-result.json` for verification-only runs. `SMOKE_DECLARED_OK` means
the declarations passed; it does not imply parity with the observed baseline.
Unsupported restart-on-freeze control is recorded as an operational notice.
Sleep preferences use `pmset` rather than `systemsetup`, which emitted Error -99
in the tested Apple Silicon VM despite returning success. SMB NetBIOS defaults
use a hyphenated network name rather than the display name's spaces.

### Command directory

Direct commands live in `bin/`; supporting tools live in `scripts/`. The repository explicitly allows that path
through global Git ignore rules, and source export includes it. `bins/` is no
longer used. The earlier command-cleanup snapshots were removed with the temporary directory.

The obsolete `manage` Docker builder, `update` wrapper, unused `hl` template,
IntelliJ `idea` launcher, and `cleanmac.sh` cleanup script are no longer included. The builder passed
SSH keys as Docker build arguments and is not suitable for reuse. `emptytrash`
now shows help by default and uses Finder only with `--run`; it does not remove
system logs or quarantine history. No trash-emptying operation is part of tests.

The personal profile includes the maintained ChatGPT desktop cask (`chatgpt`)
and Obsidian. The former Codex desktop cask is not added. Other observed-only
baseline apps such as Brave, Zed, Zoom, and Google Cloud CLI are
not promoted into the installer. Their absence is an intentional profile choice,
not evidence of installer failure. The original baseline is kept unchanged.

## Current personal preference policy and App Store requirement

The personal profile manages only verified non-default differences and reviewed
intentional customizations. The 44 captured values are comparison evidence,
not automatically applied declarations. Matches and unknown/provisional
defaults remain unmanaged. Reviewed UI customizations are Dock auto-hide,
title-bar Fill, margin-free tiling, Finder path bar on, icon view, and new
Finder windows at Desktop (seven preference writes including the Desktop URL).
Filename extensions remain at the macOS default without an explicit write.
Magnification, Dock position, and the minimize animation are left to macOS.
List and audit operate only on managed preferences. The reference analysis
is evidence-limited: macOS 15.8.2 on the host vs 15.7.7 in the vanilla reference;
35 captured values match the reference, Bluetooth trackpad tap-to-click differs,
and eight have no readable reference value. See
`install/macos/defaults/README.md` for the repeatable capture/compare rule.

Regression checks ensure matching defaults and unverified preferences do not
generate writes. The earlier 47-value VM audit predates this narrower policy;
a fresh VM run is required after the setting-by-setting review is complete.

Windows App is included, Android Studio remains, and IntelliJ is excluded.
uBlock Origin Lite is selected as App Store ID 6745342698. `mas get` requires an
Apple Account in the App Store and may require per-app authentication. No
credentials are accepted or saved by the installer. Core setup continues when
that app is pending, but the installer exits 2 and verification reports partial.
After signing in, run `bin/dotfiles appstore run`, then verify again. Safari
extension enablement still requires a user action in Safari Settings.

The guest records `appstore-status.json` and separates core installation from
pending App Store setup in its result files. App Store failures/timeouts do not
become successful declarations, and authentication output is not recorded.
The repeat-install regression also covers jenv's Bash export hook reading an
unset PROMPT_COMMAND under strict shell mode.


## Shared editor regression checks

`python3 tests/test_editors.py` uses temporary homes, fixture extension registries,
and a fake VS Code installer. It checks JSONC strings/comments, dry-run isolation,
idempotent backups, preservation of unrelated settings, local overrides, settings
and extension drift, version checks, disabled extensions, and installation failures.
It is included in `bash scripts/check.sh` and existing macOS/Linux CI jobs.

On a real device, run `dotfiles editors apply --dry-run`, then `apply` and `check`.
Launch Zed before the final check if extensions are pending. An extension manifest
proves configuration/installation, not that an LSP has indexed a project; verify
format-on-save in a scratch project for language-server acceptance. Shared policy
does not promise identical Java output (Oracle versus JDTLS) or identical independent
Prettier/Ruff fallback versions. Pin formatter versions and configs per project.
