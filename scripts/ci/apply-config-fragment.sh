#!/usr/bin/env bash
set -euo pipefail

enable_target=""
package_enable=""
package_disable=""
fragment=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable-target)
      enable_target="$2"
      shift 2
      ;;
    --package-enable)
      package_enable="$2"
      shift 2
      ;;
    --package-disable)
      package_disable="$2"
      shift 2
      ;;
    --fragment)
      fragment="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f .config ]]; then
  echo ".config not found" >&2
  exit 1
fi

python3 - <<'PY' "$enable_target" "$package_enable" "$package_disable" "$fragment"
from pathlib import Path
import re
import sys

enable_target, package_enable, package_disable, fragment = sys.argv[1:5]
config_path = Path('.config')
lines = config_path.read_text().splitlines()

all_device_re = re.compile(r'^CONFIG_TARGET_DEVICE_mediatek_filogic_DEVICE_[^=]+=y$')

result = []
for line in lines:
    if line == 'CONFIG_TARGET_MULTI_PROFILE=y':
        result.append('# CONFIG_TARGET_MULTI_PROFILE is not set')
        continue
    if all_device_re.match(line):
        continue
    result.append(line)

forced = [
    'CONFIG_TARGET_mediatek=y',
    'CONFIG_TARGET_mediatek_filogic=y',
]
if enable_target:
    forced.append(f'CONFIG_TARGET_mediatek_filogic_DEVICE_{enable_target}=y')

for item in forced:
    if item not in result:
        result.append(item)

for pkg in package_enable.split():
    result.append(f'CONFIG_PACKAGE_{pkg}=y')

for pkg in package_disable.split():
    result.append(f'# CONFIG_PACKAGE_{pkg} is not set')

if fragment.strip():
    result.append(fragment.rstrip())

config_path.write_text('\n'.join(result) + '\n')
PY
