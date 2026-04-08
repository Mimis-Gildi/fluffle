#!/usr/bin/env zsh

echo "upgraded=false" > "$GITHUB_OUTPUT"
[[ -s "$SDKMAN_INIT" ]] && source "$SDKMAN_INIT"

sdk update

readonly actual=$(sdk current java 2>/dev/null | awk '{ print $NF }') || exit 0
#readonly latest=$(sdk list java 2>/dev/null | grep -oE '21\.[0-9.]+\-tem' | sort -V | tail -n1) || exit 0
readonly latest='21.0.8-tem'

printf '<==| Upgrade to Java: %s -> %s.\n' "$latest" "$actual"

[[ "$actual" == "$latest" ]] && exit 0

sdk install java "$latest"
sdk default java "$latest"
sdk remove java "$actual"
sdk flush tmp
sdk flush metadata
sdk flush version

echo "upgraded=true" > "$GITHUB_OUTPUT"
