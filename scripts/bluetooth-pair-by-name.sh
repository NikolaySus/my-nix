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
readonly pair_seconds=60
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
  echo "Pairing; automatically accepting BlueZ's numeric confirmation..."
  # bluetoothctl 5.87 can exit successfully even after printing a pairing
  # failure, so verify BlueZ's device state instead of trusting its status.
  DEVICE_ADDRESS="$address" PAIR_SECONDS="$pair_seconds" expect <<'EXPECT_EOF' || true
set timeout $env(PAIR_SECONDS)
spawn bluetoothctl

send -- "agent KeyboardDisplay\r"
expect {
    -re {Agent registered|Agent is already registered} {}
    timeout { exit 124 }
}

send -- "default-agent\r"
expect {
    -re {Default agent request successful|Failed to request default agent} {}
    timeout { exit 124 }
}

send -- "pair $env(DEVICE_ADDRESS)\r"
expect {
    -re {Confirm passkey.*\(yes/no\):} {
        send -- "yes\r"
        exp_continue
    }
    -re {Authorize service.*\(yes/no\):} {
        send -- "yes\r"
        exp_continue
    }
    -re {Pairing successful} { exit 0 }
    -re {Failed to pair:.*} { exit 1 }
    timeout { exit 124 }
    eof { exit 1 }
}
EXPECT_EOF
  if ! bluetoothctl info "$address" 2>/dev/null | grep -Eq '^\s*Paired: yes$'; then
    echo >&2
    echo "Pairing failed." >&2
    echo "Put '$device_name' into pairing mode (not merely powered on) and retry." >&2
    echo "If it still fails, make the device forget its old host bond or reset its" >&2
    echo "Bluetooth pairings; the device may retain a key that this adapter lost." >&2
    exit 1
  fi
else
  echo "The device is already paired."
fi

bluetoothctl trust "$address"
bluetoothctl connect "$address"
echo "$device_name is paired, trusted, and connected."
