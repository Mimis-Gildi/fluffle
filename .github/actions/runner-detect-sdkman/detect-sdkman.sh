#!/usr/bin/env zsh

readonly floor_sdkman="$1"
readonly floor_native="$2"

[[ -s "$SDKMAN_INIT" ]] && source "$SDKMAN_INIT"
printf '::notice title=SDKMAN sourced::sdkman_init=%s, floor_sdkman=%s, floor_native=%s\n' "${SDKMAN_INIT:-}" "$floor_sdkman" "$floor_native"

sdk

sdk version

sdk_output=$(sdk version 2>/dev/null) && printf '::notice title=SDKMAN version response:sdkman_version=%s\n' "${sdk_output:-}" || exit 0

readonly actual_sdkman=$(echo "$sdk_output" | awk '/^script:/ { print $2 }')
readonly actual_native=$(echo "$sdk_output" | awk '/^native:/ { print $2 }')
printf '::notice title=SDKMAN parsed versions::sdkman=%s native=%s\n' "$actual_sdkman" "$actual_native"

behind() { [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$1" ]] }

if behind "$floor_sdkman" "$actual_sdkman" || behind "$floor_native" "$actual_native"; then
  printf '::warning title=SDKMAN behind floor::sdkman %s (floor %s), native %s (floor %s)\n' \
    "$actual_sdkman" "$floor_sdkman" "$actual_native" "$floor_native"
  echo "failed=true" >> "$GITHUB_OUTPUT"
else
  echo "failed=false" >> "$GITHUB_OUTPUT"
fi
