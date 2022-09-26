#!/usr/bin/env python

"""
Restoring files.
Restore files from backup into home.
"""

import os
import shutil

DOTFILES_DIR = os.path.dirname(os.path.abspath(__file__))
BACKUP_DIR   = os.path.join(DOTFILES_DIR, 'backup')
HOME_DIR     = os.path.expanduser('~')

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
    if os.path.exists(BACKUP_DIR):
        os.chdir(BACKUP_DIR)
        for filename in os.listdir(BACKUP_DIR):
            dest = os.path.join(HOME_DIR, filename)
            if os.path.exists(dest):
                force_remove(dest)
            copy(filename, dest)
            print(f"{dest} has been restored!")
    else:
        print(f"There isn't backup in {BACKUP_DIR}!")

if __name__ == '__main__':
    main()
