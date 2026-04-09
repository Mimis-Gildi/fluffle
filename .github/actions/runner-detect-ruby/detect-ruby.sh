#!/usr/bin/env zsh

readonly expected_ruby="$1"
readonly floor_gems="$2"
readonly floor_bundler="$3"

readonly actual_ruby=$(ruby --version 2>/dev/null | awk '{ print $2 }') || exit 0
readonly actual_gems=$(gem --version 2>/dev/null) || exit 0
readonly actual_bundler=$(bundle --version 2>/dev/null | awk '{ print $3 }') || exit 0

behind() { [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" != "$1" ]] }

failed=false
[[ "$actual_ruby" != "$expected_ruby" ]] && failed=true
behind "$floor_gems" "$actual_gems" && failed=true
behind "$floor_bundler" "$actual_bundler" && failed=true

if [[ "$failed" == "true" ]]; then
  printf '::warning title=Ruby toolchain::ruby %s (exact %s), gems %s (floor %s), bundler %s (floor %s)\n' \
    "$actual_ruby" "$expected_ruby" "$actual_gems" "$floor_gems" "$actual_bundler" "$floor_bundler"
  echo "failed=true" > "$GITHUB_OUTPUT"
fi
