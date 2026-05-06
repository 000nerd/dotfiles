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
./test.sh
```

Inside the container, run:
```bash
./install.sh
```

## 3. Local macOS Testing (Virtualization)

Since macOS cannot be run in Docker, you should use a Virtual Machine for a clean test.

### Option A: Tart (CLI-based, Recommended for Apple Silicon)

[Tart](https://github.com/cirruslabs/tart) is a lightweight virtualization tool for macOS on Apple Silicon.

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
./test_macos_logic.sh
```

This runs the installer against a temporary `HOME`, forces the installer down the macOS branch, and captures intended macOS commands to `/private/tmp/dotfiles-macos-logic-test/macos-commands.log` instead of executing them.
