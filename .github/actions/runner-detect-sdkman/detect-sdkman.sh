#!/usr/bin/env zsh
set -uo pipefail

readonly floor_sdkman="$1"
readonly floor_native="$2"

[[ "$(uname -s)" != "Linux" ]] && { echo "failed=false" >> "$GITHUB_OUTPUT"; exit 0 }
printf '::notice title=InLinux::pass'

source "$SDKMAN_DIR/bin/sdkman-init.sh" 2>/dev/null || { echo "failed=false" >> "$GITHUB_OUTPUT"; exit 0 }
sdk_output=$(sdk version 2>/dev/null)     || { echo "failed=false" >> "$GITHUB_OUTPUT"; exit 0 }

readonly actual_sdkman=$(echo "$sdk_output" | awk '/^script:/ { print $2 }')
readonly actual_native=$(echo "$sdk_output" | awk '/^native:/ { print $2 }')
printf '::notice title=SDKMAN out::sdk_output=%s' "$sdk_output"
printf '::notice title=SDKMAN::actual_sdkman=%s' "$actual_sdkman"
printf '::notice title=SDKMAN::actual_native=%s' "$actual_native"

behind() { [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$1" ]] }

if behind "$floor_sdkman" "$actual_sdkman" || behind "$floor_native" "$actual_native"; then
  printf '::warning title=SDKMAN behind floor::sdkman %s (floor %s), native %s (floor %s)\n' \
    "$actual_sdkman" "$floor_sdkman" "$actual_native" "$floor_native"
  echo "failed=true" >> "$GITHUB_OUTPUT"
else
  echo "failed=false" >> "$GITHUB_OUTPUT"
fi
