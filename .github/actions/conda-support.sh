#!/usr/bin/env zsh

readonly conda_home=$HOME/miniforge3
readonly conda_bin=$conda_home/bin
readonly conda_which=$conda_bin/conda
readonly mamba_which=$conda_bin/mamba

conda_info() {
  local info=$(conda info)
  printf '### %s: shell level %s, env %s\n\n```\n%s\n```\n\n' $1 ${CONDA_SHLVL:-none} ${CONDA_DEFAULT_ENV:-none} $info >> $GITHUB_STEP_SUMMARY
  print -r -- $info
}

conda_remove() {
  pushd $HOME && {
    {
      print '```text'

      rm -v .condarc
      rm -rv .conda .config/conda .local/share/conda-pypi

      pushd miniforge3 && {
        rm -r *
        rm -v .condarc
        rm -v .nonadmin
        rm -v .installer.info
      } always {
        popd
      }

      print '```'
    } >>& $GITHUB_STEP_SUMMARY
  } always {
    popd
  }
}

conda_remove_remaining() {
  print -rl -- $HOME/{.condarc,.conda/**/*,.config/conda/**/*,.local/share/conda-pypi/**/*}(D.N) $HOME/miniforge3/**/*(D.N)
}

conda_install() {
  local -r INSTALLER_WORKING_DIRECTORY="${TMPDIR:-/tmp}/installers/miniforge"
  local -r FORGE_VERSION="Miniforge3"
  local -r FORGE_PRODUCT="$FORGE_VERSION-$(uname)-$(uname -m)"
  local -r FORGE_SCRIPT="$FORGE_PRODUCT.sh"
  local -r FORGE_ARTIFACT="https://github.com/conda-forge/miniforge/releases/latest/download/$FORGE_SCRIPT"

  mkdir -p "$INSTALLER_WORKING_DIRECTORY"
  pushd "$INSTALLER_WORKING_DIRECTORY" && {
    curl -L -O "$FORGE_ARTIFACT"
    chmod +x "$FORGE_SCRIPT"
    ./"$FORGE_SCRIPT" -bu

  } always {
    popd
  }
}

conda_create_ml(){
  conda create -y -n $1 -c conda-forge python=$2 \
    lightgbm xgboost catboost imbalanced-learn seaborn matplotlib \
    shap optuna kagglehub notebook itables jproperties hatch diagrams \
    black argcomplete bottleneck pytest pyfunctional fastapi scikit-learn
}