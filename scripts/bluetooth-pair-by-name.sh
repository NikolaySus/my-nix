#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: bluetooth-pair-by-name DEVICE_NAME"
  echo
  echo "Put the device in pairing mode first. The name match is case-insensitive."
}

if (($# == 0)); then
  usage >&2
  exit 2
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

readonly device_name="$*"
readonly scan_seconds=20
scanner_pid=""

stop_scan() {
  bluetoothctl scan off >/dev/null 2>&1 || true
  if [[ -n "$scanner_pid" ]]; then
    kill "$scanner_pid" >/dev/null 2>&1 || true
    wait "$scanner_pid" 2>/dev/null || true
  fi
}
trap stop_scan EXIT

bluetoothctl power on >/dev/null
bluetoothctl pairable on >/dev/null

echo "Scanning for '$device_name' for up to $scan_seconds seconds..."
{
  echo "scan on"
  sleep "$scan_seconds"
  echo "scan off"
  echo "quit"
} | bluetoothctl >/dev/null 2>&1 &
scanner_pid=$!

address=""
for ((second = 0; second < scan_seconds; second++)); do
  mapfile -t matches < <(
    bluetoothctl devices | while read -r prefix candidate candidate_name; do
      if [[ "$prefix" == "Device" && "${candidate_name,,}" == "${device_name,,}" ]]; then
        printf '%s\n' "$candidate"
      fi
    done
  )

  if ((${#matches[@]} > 1)); then
    echo "Refusing: more than one discovered device is named '$device_name':" >&2
    printf '  %s\n' "${matches[@]}" >&2
    exit 1
  elif ((${#matches[@]} == 1)); then
    address="${matches[0]}"
    break
  fi

  sleep 1
done

if [[ -z "$address" ]]; then
  echo "No device named '$device_name' was found." >&2
  echo "Ensure it is in pairing mode, then try again." >&2
  exit 1
fi

stop_scan
trap - EXIT

echo "Found $device_name ($address)."
if ! bluetoothctl info "$address" | grep -Eq '^\s*Paired: yes$'; then
  echo "Pairing; confirm the passkey if prompted..."
  bluetoothctl --agent KeyboardDisplay pair "$address"
else
  echo "The device is already paired."
fi

bluetoothctl trust "$address"
bluetoothctl connect "$address"
echo "$device_name is paired, trusted, and connected."
