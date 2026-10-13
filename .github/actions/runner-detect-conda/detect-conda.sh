#!/usr/bin/env zsh

readonly py_base_required=$1
readonly py_ml_required=$2
readonly conda_required=$3
readonly mamba_required=$4
readonly py_env=$5

source ${0:A:h}/../runner_support.sh
source ${0:A:h}/../conda-support.sh

[[ -x $conda_which ]] || run_error "no conda at $conda_which" 0
[[ -x $mamba_which ]] || run_error "no mamba at $mamba_which" 0

printf '::notice title=Conda at job init::shell level %s, env %s\n' ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none}

readonly activation=${0:A:h}/../conda-activate.sh
[[ -s $activation ]] && source $activation
(( $+functions[conda] )) || run_error "conda not activated" 0
(( $+functions[mamba] )) || run_error "mamba not activated" 0

printf '::notice title=Conda after activation hook::shell level %s, env %s\n' ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none}
conda_info 'Conda after activation hook' > /dev/null

readonly conda_base=$(conda info --base)
[[ $conda_base == $conda_home ]] || run_error "conda base is ${conda_base:-none}, expected $conda_home" 0

readonly conda_version=$(conda --version | awk '/^conda/ { print $2 }')
readonly mamba_version=$(mamba --version)
[[ -n $conda_version ]] || run_error "conda --version gives no version" 0
[[ -n $mamba_version ]] || run_error "mamba --version gives no version" 0

channels=$(conda config --show channels) || run_error "conda config --show channels failed" 0
[[ -n $(print $channels | awk '/^ *- / && $2 == "conda-pypi"') ]] && {
  printf '::warning title=Conda channels drift::conda-pypi channel present\n'
  print 'failed=true' > $GITHUB_OUTPUT
}

priority=$(conda config --show channel_priority) || run_error "conda config --show channel_priority failed" 0
[[ $(print $priority | awk '{ print $2 }') == strict ]] || {
  printf '::warning title=Conda priority drift::channel_priority is not strict\n'
  print 'failed=true' > $GITHUB_OUTPUT
}

while (( CONDA_SHLVL > 1 )); do
  conda deactivate
  printf '::notice title=Conda deactivate::shell level %s, env %s\n' ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none}
  conda_info 'Conda deactivate' > /dev/null
done
readonly base_info=$(conda_info 'Conda base')
readonly base_location=$(print $base_info | awk -F' : ' '/active env location/ { print $2 }')
[[ $base_location == $conda_home ]] || run_error "conda deactivate lands in ${base_location:-none}, expected $conda_home" 0

readonly py_base_version=$(python --version | awk '/^Python/ { print $2 }')
[[ -n $py_base_version ]] || run_error "python --version in base gives no version" 0
[[ $py_base_version == 3.12.* ]] && run_error "base Python $py_base_version pinned to 3.12, base must be recreated" 0

behind $py_base_required $py_base_version && {
  printf '::warning title=Python is behind::base Python %s, floor %s\n' $py_base_version $py_base_required
  print 'failed=true' > $GITHUB_OUTPUT
}

behind $conda_required $conda_version && {
  printf '::warning title=Conda is behind::Conda %s, floor %s\n' $conda_version $conda_required
  print 'failed=true' > $GITHUB_OUTPUT
}

behind $mamba_required $mamba_version && {
  printf '::warning title=Mamba is behind::Mamba %s, floor %s\n' $mamba_version $mamba_required
  print 'failed=true' > $GITHUB_OUTPUT
}

envs=$(conda env list) || run_error "conda env list failed" 0
printf '### Conda envs\n\n```text\n%s\n```\n\n' $envs >> $GITHUB_STEP_SUMMARY

if [[ -n $(print $envs | awk -v env=$py_env '$1 == env') ]]; then
  ml_packages=$(conda list -n $py_env) || run_error "conda list -n $py_env failed" 0
  [[ -n $(print $ml_packages | awk '$1 == "conda"') ]] && run_error "conda core installed in $py_env, base must be recreated" 0
  conda activate $py_env
  if [[ $(conda_info "Conda $py_env" | awk -F' : ' '/active environment/ { print $2 }') == $py_env ]]; then
    readonly py_ml_version=$(python --version | awk '/^Python/ { print $2 }')
    behind $py_ml_required ${py_ml_version:-0.0.0} && {
      printf '::warning title=Python is behind::%s Python %s, floor %s\n' $py_env ${py_ml_version:-none} $py_ml_required
      print 'failed=true' > $GITHUB_OUTPUT
    }
  else
    run_error "$py_env exists but does not activate" 0
  fi
else
  printf '::warning title=Conda %s missing::no %s environment\n' $py_env $py_env
  print 'failed=true' > $GITHUB_OUTPUT
fi

printf '::notice title=Conda stack::base Python %s, %s Python %s, Conda %s, Mamba %s\n' $py_base_version $py_env ${py_ml_version:-none} $conda_version $mamba_version
