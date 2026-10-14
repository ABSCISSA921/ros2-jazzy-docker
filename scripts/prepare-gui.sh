#!/usr/bin/env bash
# Run as the desktop user. No xhost access-control changes are needed.
set -euo pipefail

# Resolve symlinks so autostart always records the actual repository path.
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
action="${1:-}"
case "$action" in
  ''|--start|--install-autostart) ;;
  *) echo "Usage: $0 [--start|--install-autostart]" >&2; exit 2 ;;
esac

if [[ "$action" == --install-autostart ]]; then
  python3 - "$project_dir" <<'PY'
import os
import pathlib
import sys

project = pathlib.Path(sys.argv[1])
config = pathlib.Path(os.environ.get('XDG_CONFIG_HOME', str(pathlib.Path.home() / '.config')))
target = config / 'autostart' / 'ros2-docker-gui.desktop'
target.parent.mkdir(parents=True, exist_ok=True)
script = str(project / 'scripts' / 'prepare-gui.sh')
for char in ('\\', '"', '`', '$'):
    script = script.replace(char, '\\' + char)
script = script.replace('%', '%%')
target.write_text('[Desktop Entry]\nType=Application\nName=ROS 2 Docker GUI\n'
                  'Comment=Refresh ROS 2 container display authorization at login\n'
                  f'Exec="{script}" --start\nTerminal=false\n'
                  'X-GNOME-Autostart-enabled=true\nX-GNOME-Autostart-Delay=5\n')
print(f'Installed {target}')
PY
  exit 0
fi

for program in xauth xdpyinfo python3; do
  command -v "$program" >/dev/null || { echo "Missing host dependency: $program" >&2; exit 1; }
done

# Also support invocation from a terminal outside the graphical session.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
if [[ -z "${DISPLAY:-}" || -z "${XAUTHORITY:-}" ]]; then
  while IFS='=' read -r key value; do
    case "$key" in
      DISPLAY) export DISPLAY="${DISPLAY:-$value}" ;;
      XAUTHORITY) export XAUTHORITY="${XAUTHORITY:-$value}" ;;
    esac
  done < <(systemctl --user show-environment 2>/dev/null || true)
fi
: "${DISPLAY:?Run this script from a logged-in X11/XWayland desktop session}"
xdpyinfo -display "$DISPLAY" >/dev/null

umask 077
mkdir -p "$project_dir/.runtime/gui"
chmod 700 "$project_dir/.runtime" "$project_dir/.runtime/gui"
cookie_file="$(mktemp "$project_dir/.runtime/gui/.Xauthority.XXXXXX")"
trap 'rm -f "$cookie_file"' EXIT
# FamilyWild allows the same cookie to work with the container's hostname.
records="$(xauth nlist "$DISPLAY")"
if [[ -z "$records" ]]; then
  echo "No X11 authorization cookie found for $DISPLAY" >&2
  exit 1
fi
printf '%s\n' "$records" | sed 's/^..../ffff/' | xauth -f "$cookie_file" nmerge -
unset records
chmod 600 "$cookie_file"
mv -f "$cookie_file" "$project_dir/.runtime/gui/Xauthority"
trap - EXIT

python3 - "$project_dir/.env" <<'PY'
import os
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
template = path.with_name('.env.example')
lines = (path.read_text() if path.exists() else template.read_text()).splitlines()
lines = [line for line in lines if not re.match(r'^\s*(?:export\s+)?DISPLAY\s*=', line)]
if not any(re.match(r'^\s*(?:export\s+)?HOST_HOME_DIR\s*=', line) for line in lines):
    lines.append('HOST_HOME_DIR=${HOME}')
lines.append('DISPLAY=' + os.environ['DISPLAY'])
path.write_text('\n'.join(lines) + '\n')
PY
echo "GUI authorization refreshed for DISPLAY=$DISPLAY"

if [[ "$action" == --start ]]; then
  cd "$project_dir"
  # Compose reads the GPU choice, project name and image from the local .env.
  # Do not download/build an image from an automatic desktop-login action.
  docker compose up -d --no-build --pull never ros2
fi
