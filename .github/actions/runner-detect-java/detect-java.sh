#!/usr/bin/env zsh

source "$SDKMAN_INIT"
sdk version

sdk update
sdk flush tmp
sdk flush metadata
sdk flush version

readonly actual=$(sdk current java 2>/dev/null | awk '{ print $NF }') || exit 0
readonly latest=$(sdk list java 2>/dev/null | grep -oE '21\.[0-9.]+\-tem' | sort -V | tail -n1) || exit 0

if [[ "$actual" != "$latest" ]]; then
  printf '::warning title=Java outdated::active is %s while latest is %s\n' "$actual" "$latest"
  echo "failed=true" > "$GITHUB_OUTPUT"
else
  printf '::notice title=Java OK::%s.\n' "$actual"
fi
