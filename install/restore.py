#!/usr/bin/env python

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

# copy path to dest
def copy(path, dest):
    if os.path.isdir(path):
        shutil.copytree(path, dest)
    else:
        shutil.copy(path, dest)

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
        os.chdir(backup_dir)
        for filename in os.listdir(backup_dir):
            dest = os.path.join(HOME_DIR, filename)
            if args.dry_run:
                print(f"Would restore {filename} to {dest}")
            else:
                if os.path.exists(dest):
                    force_remove(dest)
                copy(filename, dest)
                print(f"{dest} has been restored!")
    else:
        print(f"There isn't backup in {backup_dir}!")

if __name__ == '__main__':
    main()
