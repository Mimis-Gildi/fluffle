#!/usr/bin/env zsh

readonly java_major=$1
readonly java_vendor=$2

print 'failed=true' > $GITHUB_OUTPUT

export RUST_BACKTRACE=1
source $SDKMAN_INIT

readonly actual=$(sdk current java | awk '{ print $NF }')
[[ ! $actual ]] && {
  print '::warning title=Java not installed::no version configured'
  exit 0
}

readonly latest=$(sdk list java | awk -v want="^${java_major}([.][0-9]+)+-${java_vendor}\$" '{ for (i=1;i<=NF;i++) if ($i ~ want) print $i }' | sort -V | tail -n1)
[[ $actual != $latest ]] && {
  printf '::warning title=Java outdated::active %s, latest %s\n' $actual $latest
  exit 0
}

printf '::notice title=Java OK::%s\n' $actual
print 'failed=false' > $GITHUB_OUTPUT
