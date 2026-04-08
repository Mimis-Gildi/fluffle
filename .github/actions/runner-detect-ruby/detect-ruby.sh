#!/usr/bin/env zsh

readonly expected="$1"
readonly actual=$(ruby --version 2>/dev/null | awk '{ print $2 }') || exit 0

if [[ "$actual" != "$expected" ]]; then
  printf '::warning title=Ruby mismatch::expected %s, found %s\n' "$expected" "$actual"
  echo "failed=true" > "$GITHUB_OUTPUT"
fi
