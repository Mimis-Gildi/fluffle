#!/usr/bin/env zsh

print 'failed=true' > $GITHUB_OUTPUT

readonly candidate=$1

export RUST_BACKTRACE=1
source $SDKMAN_INIT

readonly actual=$(sdk current $candidate | awk '{ print $NF }')
readonly latest=$(sdk list $candidate | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n1)

if [[ $actual != $latest ]]; then
  printf '::warning title=%s outdated::active %s, latest %s\n' $candidate $actual $latest
else
  printf '::notice title=%s Okay::%s\n' $candidate $actual
  print 'failed=false' > $GITHUB_OUTPUT
fi
