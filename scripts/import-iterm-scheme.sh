#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
    echo "This importer requires iTerm on macOS." >&2
    exit 1
fi
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Keep filenames and preset contents as data; never construct shell commands.
python3 - "$ROOT_DIR/config/themes/iterm" "$@" <<'PY'
import argparse
import datetime
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import sys
import tempfile

schemes = Path(sys.argv[1])
parser = argparse.ArgumentParser(prog="import-iterm-scheme.sh")
parser.add_argument("-v", "--verbose", action="store_true")
parser.add_argument("schemes", nargs="+", help="Bundled preset names or .itermcolors paths")
args = parser.parse_args(sys.argv[2:])

try:
    imports = {}
    for argument in args.schemes:
        source = Path(argument).expanduser()
        if not source.is_file():
            for bundled in (schemes / source.name, schemes / (source.name + ".itermcolors")):
                if bundled.is_file():
                    source = bundled
                    break
        if not source.is_file() or source.suffix != ".itermcolors":
            raise ValueError("Not an iTerm color file: " + argument)
        name = " ".join(source.stem.replace("_", " ").replace("-", " ").split()).title()
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9 .-]*", name):
            raise ValueError("Unsupported preset name: " + source.stem)
        with source.open("rb") as stream:
            colors = plistlib.load(stream)
        if not isinstance(colors, dict):
            raise ValueError("Color preset must contain a dictionary: " + str(source))
        imports[name] = colors
        if args.verbose:
            print("Read preset " + name + " from " + str(source))

    preferences = Path.home() / "Library/Preferences/com.googlecode.iterm2.plist"
    if preferences.is_symlink():
        preferences = preferences.resolve()
    before = preferences.read_bytes() if preferences.exists() else None
    data = plistlib.loads(before) if before else {}
    if not isinstance(data, dict):
        raise ValueError("iTerm preferences must contain a dictionary")
    presets = data.get("Custom Color Presets", {})
    if not isinstance(presets, dict):
        raise ValueError("Custom Color Presets must contain a dictionary")
    updated = {**presets, **imports}
    if before is not None and updated == presets:
        print("Presets already imported; no changes.")
        sys.exit(0)
    data["Custom Color Presets"] = updated
    preferences.parent.mkdir(parents=True, exist_ok=True)
    format_ = plistlib.FMT_BINARY if before and before.startswith(b"bplist00") else plistlib.FMT_XML
    with tempfile.NamedTemporaryFile(dir=preferences.parent, prefix=".iterm-colors-", delete=False) as stream:
        temporary = Path(stream.name)
        try:
            plistlib.dump(data, stream, fmt=format_, sort_keys=False)
            stream.flush()
            if before is not None:
                stamp = datetime.datetime.now().strftime("%Y%m%d%H%M%S%f")
                shutil.copy2(preferences, preferences.with_name(preferences.name + ".bak." + stamp))
                os.chmod(temporary, stat.S_IMODE(preferences.stat().st_mode))
            os.replace(temporary, preferences)
        finally:
            temporary.unlink(missing_ok=True)
    print("Imported presets: " + ", ".join(imports))
except (OSError, ValueError, plistlib.InvalidFileException) as error:
    parser.exit(1, "error: " + str(error) + "\n")
PY
