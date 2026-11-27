#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"
export PYTHONDONTWRITEBYTECODE=1

# bash -n takes one script, not a list of scripts to parse.
for file in install.sh bin/dotfiles; do bash -n "$file"; done
while IFS= read -r -d '' file; do
    bash -n "$file"
done < <(find install scripts tests -type f -name '*.sh' -print0)
if command -v zsh >/dev/null 2>&1; then
    for file in config/zsh/* config/themes/zsh/*.zsh-theme; do
        [ -f "$file" ] || continue
        zsh -n "$file"
    done
fi
python3 - <<'PY'
from pathlib import Path
import subprocess
import shutil
for directory in ('install', 'scripts', 'tests'):
    for path in Path(directory).rglob('*.py'):
        compile(path.read_bytes(), str(path), 'exec')
for path in Path('bin').iterdir():
    if not path.is_file():
        continue
    header = path.read_bytes().split(b'\n', 1)[0].decode(errors='replace')
    if header.startswith('#!'):
        if 'zsh' in header:
            if shutil.which('zsh'):
                subprocess.run(['zsh', '-n', str(path)], check=True)
        elif 'bash' in header or header.endswith('/sh') or header.endswith(' sh'):
            subprocess.run(['bash', '-n', str(path)], check=True)
PY
python3 tests/test_setup.py
python3 tests/test_editors.py
python3 tests/test_codex_theme.py
./tests/test_dotfiles_help.sh
./tests/test_macos_logic.sh
./tests/test_macos_defaults.sh
./tests/test_theme_logic.sh
