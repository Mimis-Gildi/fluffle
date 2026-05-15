#!/usr/bin/env zsh

print 'failed=true' > $GITHUB_OUTPUT

readonly candidate=$1

export RUST_BACKTRACE=1
source $SDKMAN_INIT

readonly actual=$(sdk current $candidate | awk '{ print $NF }')
[[ ! $actual ]] && {
  printf '::warning title=%1$s not installed:: %1$s\n' $candidate
  exit 0
}

readonly latest=$(sdk list $candidate | awk '{ for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) print $i }' | sort -V | tail -n1)
[[ $actual != $latest ]] && {
  printf '::warning title=%1$s outdated::active %2$s, latest %3$s\n' $candidate $actual $latest
  exit 0
}

printf '::notice title=%1$s Okay::%2$s\n' $candidate $actual
print 'failed=false' > $GITHUB_OUTPUT
