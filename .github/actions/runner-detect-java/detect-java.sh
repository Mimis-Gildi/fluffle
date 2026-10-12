#!/usr/bin/env zsh

readonly java_major=$1
readonly java_vendor=$2

print 'failed=true' > $GITHUB_OUTPUT

source ${0:A:h}/../runner_support.sh

readonly actual=$(sdk_current_version_of_candidate java)
[[ ! $actual ]] && {
  print '::warning title=Java not installed::no version configured'
  exit 0
}

readonly latest=$(sdk_latest_java_of_major_and_vendor $java_major $java_vendor)
[[ $actual != $latest ]] && {
  printf '::warning title=Java outdated::active %s, latest %s\n' $actual $latest
  exit 0
}

printf '::notice title=Java OK::%s\n' $actual
print 'failed=false' > $GITHUB_OUTPUT
