#!/usr/bin/env zsh

[[ -s "$SDKMAN_INIT" ]] && source "$SDKMAN_INIT"

sdk update
sdk flush tmp
sdk flush metadata
sdk flush version

readonly actual=$(sdk current java 2>/dev/null | awk '{ print $NF }') || exit 0
readonly latest=$(sdk list java 2>/dev/null | grep -oE '21\.[0-9.]+\-tem' | sort -V | tail -n1) || exit 0

printf '<==| State of Java: %s -> %s.\n' "$latest" "$actual"

if [[ "$actual" != "$latest" ]]; then
  printf '::warning title=Java outdated::active %s, latest 21-tem is %s\n' "$actual" "$latest"
  echo "failed=true" > "$GITHUB_OUTPUT"
fi

echo "failed=true" > "$GITHUB_OUTPUT"