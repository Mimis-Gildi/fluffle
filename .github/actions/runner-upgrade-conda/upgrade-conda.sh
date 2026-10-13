#!/usr/bin/env zsh

source ${0:A:h}/../runner_support.sh
source ${0:A:h}/../conda-support.sh

readonly environment_name=$1
readonly python_pinned_version=$2

print 'upgraded=false' > $GITHUB_OUTPUT

readonly activation=${0:A:h}/../conda-activate.sh
[[ -s $activation ]] && source $activation
(( $+functions[conda] )) || run_error "conda not activated" 81
(( $+functions[mamba] )) || run_error "mamba not activated" 82
conda_info 'Conda after activation hook'

while (( CONDA_SHLVL > 1 )); do
  conda deactivate || run_error "conda deactivate failed at shell level $CONDA_SHLVL" 71
  conda_info 'Conda deactivate'
done

conda_info 'Conda base'
base_info=$(conda info) || run_error "conda info failed in base" 61
readonly base_location=$(print -r -- $base_info | awk -F' : ' '/active env location/ { print $2 }')
[[ $base_location == $conda_home ]] || run_error "conda deactivate lands in ${base_location:-none}, expected $conda_home" 62

channels=$(conda config --show channels) || run_error "conda config --show channels failed" 51
priority=$(conda config --show channel_priority) || run_error "conda config --show channel_priority failed" 52
readonly user_channels=($(print -r -- $channels | awk '/^ *- / && $2 !~ /^(conda-forge|defaults|conda-pypi)$/ { print $2 }'))
readonly priority_mode=$(print -r -- $priority | awk '{ print $2 }')

[[ -n $(print -r -- $channels | awk '/^ *- / && $2 == "conda-pypi"') ]] && {
  conda config --remove channels conda-pypi || run_error "conda config --remove channels conda-pypi failed" 53
  printf '::warning title=Conda channels drift::conda-pypi channel ripped out with vengeance!\n'
  printf '### Conda channels: conda-pypi ripped out with vengeance!\n\n' >> $GITHUB_STEP_SUMMARY
}

[[ $priority_mode == strict ]] || {
  conda config --set channel_priority strict || run_error "conda config --set channel_priority strict failed" 54
  printf '::warning title=Conda priority drift::channel_priority %s set to strict\n' ${priority_mode:-none}
  printf '### Conda channels: channel_priority %s set to strict\n\n' ${priority_mode:-none} >> $GITHUB_STEP_SUMMARY
}

for channel in $user_channels; do
  conda config --remove channels $channel || run_error "conda config --remove channels $channel failed: not in user config" 55
  conda config --append channels $channel || run_error "conda config --append channels $channel failed" 56
  printf '::warning title=Conda user channel::%s appended at lowest priority\n' $channel
  printf '### Conda channels: user channel %s appended at lowest priority\n\n' $channel >> $GITHUB_STEP_SUMMARY
done

conda clean -y -a || run_error "conda first clean failed" 21
conda upgrade -y python || run_error "conda python upgrade failed" 22
conda upgrade -y conda || run_error "conda conda upgrade failed" 23
conda upgrade -y --all || run_error "conda upgrade ALL failed" 24
conda clean -y -a || run_error "conda base final clean failed" 0

if conda activate $environment_name; then
  ml_info=$(conda info) || run_error "conda info failed in $environment_name" 32
  ml_location=$(print -r -- $ml_info | awk -F' : ' '/active env location/ { print $2 }')
  [[ $ml_location == $conda_home/envs/$environment_name ]] || run_error "conda activate $environment_name lands in ${ml_location:-none}, expected $conda_home/envs/$environment_name" 33

  conda install -y python=$python_pinned_version  || run_error "conda $environment_name python pin to $python_pinned_version failed" 41
  conda upgrade -y python || run_error "conda $environment_name python upgrade failed" 42
  conda upgrade -y --all || run_error "conda $environment_name upgrade ALL failed" 43
  conda clean -y -a || run_error "conda $environment_name final clean failed" 0

  print 'upgraded=true' > $GITHUB_OUTPUT
else
  printf '::warning title=Environment %1$s missing::Will recreate %1$s and move on.\n' $environment_name
  conda_create_ml $environment_name $python_pinned_version || run_error "conda environment create failed in $environment_name" 0

  printf 'upgraded=true\ncreated=%s\n' $environment_name > $GITHUB_OUTPUT
fi

conda_info 'Conda end state'
