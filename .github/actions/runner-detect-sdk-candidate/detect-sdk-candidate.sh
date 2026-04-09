#!/usr/bin/env zsh

echo "failed=true" > "$GITHUB_OUTPUT"

readonly candidate="$1"

export RUST_BACKTRACE=1
source "$SDKMAN_INIT"

readonly actual=$(sdk current "$candidate" 2>/dev/null | awk '{ print $NF }') || exit 0
readonly latest=$(sdk list "$candidate" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n1) || exit 0

if [[ "$actual" != "$latest" ]]; then
  printf '::warning title=%s outdated::active %s, latest %s\n' "$candidate" "$actual" "$latest"
else
  printf '::notice title=%s Okay::%s\n' "$candidate" "$actual"
  echo "failed=false" > "$GITHUB_OUTPUT"
fi
