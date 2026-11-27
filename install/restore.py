#!/usr/bin/env python3

"""
Restoring files.
Restore files from backup into home.
"""

import argparse
import os
import shutil

DEFAULT_BACKUP_DIR = os.environ.get(
    "DOTFILES_BACKUP_DIR",
    os.path.join(os.path.expanduser("~"), "dotfiles-backup"),
)
HOME_DIR = os.path.expanduser("~")

# remove path
def force_remove(path):
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path, False)
    else:
        os.unlink(path)

def restore(path, dest, dry_run=False):
    """Merge directories, replacing only entries actually present in the backup.

    Do not follow either source or destination symlinks while traversing. In
    particular, .ssh/config must never cause all of .ssh to be replaced.
    """
    if os.path.isdir(path) and not os.path.islink(path):
        if os.path.lexists(dest) and (os.path.islink(dest) or not os.path.isdir(dest)):
            if not dry_run:
                force_remove(dest)
        if not dry_run:
            os.makedirs(dest, mode=0o700, exist_ok=True)
        for filename in sorted(os.listdir(path)):
            restore(os.path.join(path, filename), os.path.join(dest, filename), dry_run)
        return

    print(f"{'Would restore' if dry_run else 'Restoring'} {path} to {dest}")
    if dry_run:
        return
    if os.path.lexists(dest):
        force_remove(dest)
    if os.path.islink(path):
        os.symlink(os.readlink(path), dest)
    else:
        shutil.copy2(path, dest)

def main():
    parser = argparse.ArgumentParser(description="Restore dotfiles from backup.")
    parser.add_argument(
        "--backup-dir",
        default=DEFAULT_BACKUP_DIR,
        help="Backup directory to restore from. Defaults to ~/dotfiles-backup.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show restore actions without changing files.",
    )
    args = parser.parse_args()

    backup_dir = os.path.abspath(os.path.expanduser(args.backup_dir))

    if os.path.exists(backup_dir):
        for filename in sorted(os.listdir(backup_dir)):
            dest = os.path.join(HOME_DIR, filename)
            restore(os.path.join(backup_dir, filename), dest, args.dry_run)
    else:
        print(f"There isn't backup in {backup_dir}!")

if __name__ == '__main__':
    main()
