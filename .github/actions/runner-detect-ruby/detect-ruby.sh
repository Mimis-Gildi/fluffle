#!/usr/bin/env zsh

readonly expected_ruby=$1
readonly floor_gems=$2
readonly floor_bundler=$3

readonly actual_ruby=$(ruby --version | awk '{ print $2 }')
readonly actual_gems=$(gem --version)
readonly actual_bundler=$(bundle --version | awk '{ print $3 }')

source ${0:A:h}/../runner_support.sh

if [[ ${actual_ruby:-0} != $expected_ruby ]] || behind $floor_gems ${actual_gems:-0} || behind $floor_bundler ${actual_bundler:-0}; then
  printf '::warning title=Ruby toolchain::ruby %s (exact %s), gems %s (floor %s), bundler %s (floor %s)\n' \
    $actual_ruby $expected_ruby $actual_gems $floor_gems $actual_bundler $floor_bundler
  print 'failed=true' > $GITHUB_OUTPUT
else
  printf '::notice title=Ruby Stack OK::Ruby %s, Gems %s, Bundler %s\n' $actual_ruby $actual_gems $actual_bundler
fi
