#!/usr/bin/env sh

# Redis forks for background persistence. Linux hosts should permit memory
# overcommit so that fork does not fail when committed memory is close to the
# host limit. This setting belongs to the container host's kernel; Docker
# cannot apply vm.* sysctls from an unprivileged Compose service.

set -eu

SYSCTL_KEY="vm.overcommit_memory"
SYSCTL_VALUE="1"
SYSCTL_FILE="/etc/sysctl.d/99-omniroute-redis.conf"

usage() {
  printf 'Usage: %s [--check]\n' "$0"
}

current_value() {
  sysctl -n "$SYSCTL_KEY" 2>/dev/null || printf 'unavailable'
}

check_setting() {
  current="$(current_value)"
  if [ "$current" = "$SYSCTL_VALUE" ]; then
    printf '%s is already set to %s.\n' "$SYSCTL_KEY" "$SYSCTL_VALUE"
    return 0
  fi

  printf '%s is %s; Redis requires %s.\n' "$SYSCTL_KEY" "$current" "$SYSCTL_VALUE" >&2
  return 1
}

case "${1:-}" in
  "") ;;
  --check)
    check_setting
    exit $?
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

if [ "$(uname -s)" != "Linux" ]; then
  printf 'This script must run on the Linux host that runs Redis.\n' >&2
  exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
  mkdir -p /etc/sysctl.d
  printf '%s = %s\n' "$SYSCTL_KEY" "$SYSCTL_VALUE" > "$SYSCTL_FILE"
  sysctl -w "$SYSCTL_KEY=$SYSCTL_VALUE" >/dev/null
else
  if ! command -v sudo >/dev/null 2>&1; then
    printf 'Root access is required. Re-run as root or install sudo.\n' >&2
    exit 1
  fi
  printf '%s = %s\n' "$SYSCTL_KEY" "$SYSCTL_VALUE" | sudo tee "$SYSCTL_FILE" >/dev/null
  sudo sysctl -w "$SYSCTL_KEY=$SYSCTL_VALUE" >/dev/null
fi

check_setting
printf 'Persisted Redis host tuning in %s.\n' "$SYSCTL_FILE"
