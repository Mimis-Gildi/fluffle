#!/usr/bin/env zsh

code=0

readonly java_major=$1
readonly java_vendor=$2

print '## Upgrade Java' > $GITHUB_STEP_SUMMARY
print 'upgraded=false' > $GITHUB_OUTPUT

source ${0:A:h}/../runner_support.sh

sdk_refresh

readonly actual=$(sdk_current_version_of_candidate java)
readonly latest=$(sdk_latest_java_of_major_and_vendor $java_major $java_vendor)

if [[ $actual != $latest ]]; then
  if sdk install java $latest; then
    sdk default java $latest
    sdk use java $latest

    printf '### Set Java to %s\n\n' $latest >> $GITHUB_STEP_SUMMARY
    printf '::notice title=Java upgraded::%s -> %s\n' $actual $latest
    print 'upgraded=true' > $GITHUB_OUTPUT
  else
    tag_error "sdk install java $latest failed (current $actual)"
    code=37
  fi
fi

readonly idle=$(sdk_versions_of_candidate_marked java '^[^>]*[*+][^>]*$')

for spare in ${(@f)idle}; do
  sdk uninstall java $spare
  printf '- uninstalled idle Java %s\n' $spare >> $GITHUB_STEP_SUMMARY
done

{
  print '### Final Java State:'

  sdk current java
  sdk flush --all
} >> $GITHUB_STEP_SUMMARY

exit $code