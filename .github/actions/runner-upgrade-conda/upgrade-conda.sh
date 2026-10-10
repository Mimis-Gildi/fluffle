#!/usr/bin/env zsh

print 'upgraded=false' > $GITHUB_OUTPUT

violent() {
  printf '::error title=Conda upgrade failed::%s\n' $1
  exit 111
}

conda_info() {
  local info
  info=$(conda info) || violent "conda info failed at shell level ${CONDA_SHLVL:-none}"
  printf '### %s: shell level %s, env %s\n\n```\n%s\n```\n\n' $1 ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none} $info >> $GITHUB_STEP_SUMMARY
}

readonly conda_home=$HOME/miniforge3

readonly activation=${0:A:h}/conda-activate.sh
[[ -s $activation ]] && source $activation
conda_info 'Conda after activation hook'

while (( CONDA_SHLVL > 1 )); do
  conda deactivate || violent "conda deactivate failed at shell level $CONDA_SHLVL"
  conda_info 'Conda deactivate'
done

conda_info 'Conda base'
base_info=$(conda info) || violent "conda info failed in base"
readonly base_location=$(print -r -- $base_info | awk -F' : ' '/active env location/ { print $2 }')
[[ $base_location == $conda_home ]] || violent "conda deactivate lands in ${base_location:-none}, expected $conda_home"

channels=$(conda config --show channels) || violent "conda config --show channels failed"
priority=$(conda config --show channel_priority) || violent "conda config --show channel_priority failed"
readonly user_channels=($(print -r -- $channels | awk '/^ *- / && $2 !~ /^(conda-forge|defaults|conda-pypi)$/ { print $2 }'))
readonly priority_mode=$(print -r -- $priority | awk '{ print $2 }')

[[ -n $(print -r -- $channels | awk '/^ *- / && $2 == "conda-pypi"') ]] && {
  conda config --remove channels conda-pypi || violent "conda config --remove channels conda-pypi failed"
  printf '::warning title=Conda channels drift::conda-pypi channel ripped out with vengeance!\n'
  printf '### Conda channels: conda-pypi ripped out with vengeance!\n\n' >> $GITHUB_STEP_SUMMARY
}

[[ $priority_mode == strict ]] || {
  conda config --set channel_priority strict || violent "conda config --set channel_priority strict failed"
  printf '::warning title=Conda priority drift::channel_priority %s set to strict\n' ${priority_mode:-none}
  printf '### Conda channels: channel_priority %s set to strict\n\n' ${priority_mode:-none} >> $GITHUB_STEP_SUMMARY
}

for channel in $user_channels; do
  conda config --remove channels $channel || violent "conda config --remove channels $channel failed: not in user config"
  conda config --append channels $channel || violent "conda config --append channels $channel failed"
  printf '::warning title=Conda user channel::%s appended at lowest priority\n' $channel
  printf '### Conda channels: user channel %s appended at lowest priority\n\n' $channel >> $GITHUB_STEP_SUMMARY
done

conda clean -y -a || violent "conda first clean failed"
conda upgrade -y python || violent "conda python upgrade failed"
conda upgrade -y conda || violent "conda conda upgrade failed"
conda upgrade -y --all || violent "conda upgrade ALL failed"
conda clean -y -a || violent "conda base final clean failed"

conda activate ml || violent "conda activate ml failed"
conda_info 'Conda ml'
ml_info=$(conda info) || violent "conda info failed in ml"
readonly ml_location=$(print -r -- $ml_info | awk -F' : ' '/active env location/ { print $2 }')
[[ $ml_location == $conda_home/envs/ml ]] || violent "conda activate ml lands in ${ml_location:-none}, expected $conda_home/envs/ml"

conda upgrade -y python || violent "conda ml python upgrade failed"
conda upgrade -y --all || violent "conda ml upgrade ALL failed"
conda clean -y -a || violent "conda ml final clean failed"

print 'upgraded=true' > $GITHUB_OUTPUT

conda_info 'Conda end state'
