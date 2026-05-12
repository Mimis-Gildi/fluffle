#!/usr/bin/env zsh

export RUST_BACKTRACE=1
source $SDKMAN_INIT

readonly actual=$(sdk current java | awk '{ print $NF }')
readonly latest=$(sdk list java | grep -oE '21\.[0-9.]+\-tem' | sort -V | tail -n1)

if [[ $actual != $latest ]]; then
  printf '::warning title=Java outdated::active is %s while latest is %s\n' $actual $latest
  print 'failed=true' > $GITHUB_OUTPUT
else
  printf '::notice title=Java OK::%s.\n' $actual
fi
