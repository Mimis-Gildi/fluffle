#!/usr/bin/env zsh

export RUST_BACKTRACE=1
source $SDKMAN_INIT

tag_error() {
  printf '### FAILED: %s\n' $1 >> $GITHUB_STEP_SUMMARY
  printf '::error title=FAILED::%s\n' $1
}

run_error() {
  tag_error $1
  print 'inoperable=true' > $GITHUB_OUTPUT
  exit $2
}

behind() { [[ $(printf '%s\n%s' $1 $2 | sort -V | head -n1) != $1 ]] }

sdk_refresh() {
  sdk current
  sdk version
  sdk update
  sdk flush --all
}

sdk_current_version_of_candidate() {
  sdk current $1 | awk '{ print $NF }'
}

sdk_latest_version_of_candidate_matching() {
  sdk list $1 | awk -v want=$2 '{ for (i=1;i<=NF;i++) if ($i ~ want) { k = $i; gsub(/[+]/, ".", k); print k, $i } }' | sort -V | tail -n1 | awk '{ print $NF }'
}

sdk_latest_java_of_major_and_vendor() {
  sdk_latest_version_of_candidate_matching java "^${1}([.][0-9]+)*([+][0-9.]+)?-${2}\$"
}

sdk_latest_release_version_of_candidate() {
  sdk_latest_version_of_candidate_matching $1 '^[0-9]+[.][0-9]+[.][0-9]+$'
}

sdk_versions_of_candidate_marked() {
  sdk list $1 | awk -F'|' -v want=$2 '
    NF > 1 { if ($2 ~ want) { gsub(/ /, "", $NF); print $NF }; next }
    { n = split($0, f, " "); for (i = 1; i <= n; i++) if (f[i] ~ /^[>*+]$/) { if (f[i] ~ want) marked = 1 } else { if (marked && f[i] ~ /^[0-9]/) print f[i]; marked = 0 } }'
}

sdk_installed_versions_of_candidate() {
  sdk_versions_of_candidate_marked $1 '[*]'
}