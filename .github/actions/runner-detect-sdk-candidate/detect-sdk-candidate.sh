#!/usr/bin/env zsh

print 'failed=true' > $GITHUB_OUTPUT

readonly candidate=$1

source ${0:A:h}/../runner_support.sh

readonly actual=$(sdk_current_version_of_candidate $candidate)
[[ ! $actual ]] && {
  printf '::warning title=%1$s not installed::%1$s\n' $candidate
  exit 0
}

readonly latest=$(sdk_latest_release_version_of_candidate $candidate)
[[ $actual != $latest ]] && {
  printf '::warning title=%1$s outdated::active %2$s, latest %3$s\n' $candidate $actual $latest
  exit 0
}

printf '::notice title=%1$s OK::%2$s\n' $candidate $actual
print 'failed=false' > $GITHUB_OUTPUT
