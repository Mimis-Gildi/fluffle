#!/usr/bin/env zsh

readonly environment_name=$1
readonly python_pin=$2

print 'completed=false' > $GITHUB_OUTPUT

source ${0:A:h}/../runner_support.sh
source ${0:A:h}/../conda-support.sh

conda_remove

remaining=$(conda_remove_remaining)
[[ -n $remaining ]] && {
  printf '::error title=Conda leftovers::%s files survived rip out\n' ${#${(f)remaining}}
  printf '### Conda leftovers\n\n```text\n%s\n```\n\n' $remaining >> $GITHUB_STEP_SUMMARY
}

conda_install

readonly activation=${0:A:h}/../conda-activate.sh
[[ -s $activation ]] && source $activation
(( $+functions[conda] )) || run_error "conda not activated" 111
(( $+functions[mamba] )) || run_error "mamba not activated" 112

conda config --set channel_priority strict || run_error "conda strict channel priority setting sneezed" 0
conda_create_ml $environment_name $python_pin || run_error "conda environment create failed for $environment_name" 0

printf '### Conda installed\n\n```text\n%s\n```\n\n' "$(conda info)" >> $GITHUB_STEP_SUMMARY

print 'completed=true' > $GITHUB_OUTPUT
