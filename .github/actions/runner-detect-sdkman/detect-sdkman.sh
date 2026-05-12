#!/usr/bin/env zsh

print 'failed=true' > $GITHUB_OUTPUT

behind() { [[ $(printf '%s\n%s' $1 $2 | sort -V | head -n1) != $1 ]] }

readonly floor_sdkman=$1
readonly floor_native=$2

export RUST_BACKTRACE=1
source $SDKMAN_INIT

sdk current
sdk version
sdk update
sdk flush --all

sdk_output=$(sdk version)

readonly actual_sdkman=$(print -- $sdk_output | awk '/^script:/ { print $2 }')
readonly actual_native=$(print -- $sdk_output | awk '/^native:/ { print $2 }')


if behind $floor_sdkman $actual_sdkman || behind $floor_native $actual_native; then
  printf '::warning title=SDKMAN is behind::sdkman %s (floor %s), native %s (floor %s)\n' \
    $actual_sdkman $floor_sdkman $actual_native $floor_native
elif [[ -z $actual_sdkman || -z $actual_native ]]; then
    print '::warning title=SDKMAN BUGGED::Rust migration broke things again.'
else
  printf '::notice title=SDKMAN Okay::sdkman %s, native %s.\n' $actual_sdkman $actual_native
  print 'failed=false' > $GITHUB_OUTPUT
fi
