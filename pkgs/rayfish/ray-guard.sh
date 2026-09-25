#!/bin/sh
set -eu

real='@REAL@'
subcommand=''
for arg in "$@"; do
  case "$arg" in
    -*) continue ;;
    *) subcommand="$arg"; break ;;
  esac
done

case "$subcommand" in
  update)
    case " ${*:-} " in
      *' --check '*|*' --list '*|*' --help '*|*' -h '*) ;;
      *) echo "rayfish: self-update is disabled; update the Nix flake instead" >&2; exit 1 ;;
    esac
    ;;
  start|stop|restart)
    # Drive the service the Nix module installed, not upstream's own install.
    if [ "$(id -u)" != 0 ]; then
      echo "rayfish: '$subcommand' requires root; run with sudo" >&2
      exit 1
    fi
    if [ "$(uname -s)" = Darwin ]; then
      label='com.rayfish.vpn'
      plist="/Library/LaunchDaemons/$label.plist"
      case "$subcommand" in
        # bootout unloads the job, so KeepAlive doesn't bring it back.
        stop) exec /bin/launchctl bootout "system/$label" ;;
        start|restart)
          if /bin/launchctl print "system/$label" >/dev/null 2>&1; then
            [ "$subcommand" = restart ] && exec /bin/launchctl kickstart -k "system/$label"
            exec /bin/launchctl kickstart "system/$label"
          fi
          exec /bin/launchctl bootstrap system "$plist"
          ;;
      esac
    fi
    exec systemctl "$subcommand" rayfish.service
    ;;
  auto-update|install|uninstall)
    echo "rayfish: service management is owned by the Nix module" >&2
    exit 1
    ;;
  up)
    if [ "$(id -u)" = 0 ]; then
      echo "rayfish: root service setup is owned by the Nix module" >&2
      exit 1
    fi
    ;;
esac

exec "$real" "$@"
