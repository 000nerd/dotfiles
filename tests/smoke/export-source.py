#!/usr/bin/env python3
"""Export HEAD, or tracked + nonignored working files, without local leftovers."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile


def export(root, destination, source="working"):
    destination.mkdir(parents=True, exist_ok=False)
    head = subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"], text=True).strip()
    if source == "head":
        with tempfile.TemporaryFile() as archive:
            subprocess.run(["git", "-C", str(root), "archive", "--format=tar", "HEAD"], stdout=archive, check=True)
            archive.seek(0)
            with tarfile.open(fileobj=archive) as bundle:
                for member in bundle.getmembers():
                    relative = Path(member.name)
                    if relative.is_absolute() or ".." in relative.parts or member.islnk():
                        raise ValueError("Unsafe archive member: " + member.name)
                    # Repository symlinks are copied, never traversed by this exporter.
                    if member.issym():
                        target = Path(member.linkname)
                        if target.is_absolute() or not (destination / relative.parent / target).resolve().is_relative_to(destination.resolve()):
                            raise ValueError("Unsafe archive symlink: " + member.name)
                bundle.extractall(destination)
    else:
        paths = subprocess.check_output(["git", "-C", str(root), "ls-files", "--cached", "--others", "--exclude-standard", "-z"])
        for name in sorted(set(paths.decode().split("\0")) - {""}):
            relative = Path(name)
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError("Unsafe source path: " + name)
            origin, target = root / relative, destination / relative
            if not origin.exists() and not origin.is_symlink():
                continue  # Working-tree deletion.
            if origin.is_dir() and not origin.is_symlink():
                raise ValueError("Submodules must be exported explicitly: " + name)
            if origin.is_symlink() and not origin.resolve().is_relative_to(root):
                raise ValueError("Source symlink leaves the repository: " + name)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(origin, target, follow_symlinks=False)
    files = {}
    for path in sorted(destination.rglob("*")):
        if path.is_symlink():
            files[str(path.relative_to(destination))] = {"symlink": str(path.readlink())}
        elif path.is_file():
            files[str(path.relative_to(destination))] = {"sha256": hashlib.sha256(path.read_bytes()).hexdigest(), "mode": oct(path.stat().st_mode & 0o777)}
    (destination / ".dotfiles-source.json").write_text(json.dumps({"source": source, "head": head, "files": files}, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source", choices=("working", "head"), default="working")
    args = parser.parse_args()
    export(args.root.resolve(), args.output, args.source)
    print("Exported " + args.source + " source to " + str(args.output))
