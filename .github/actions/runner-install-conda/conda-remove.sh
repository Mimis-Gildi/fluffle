#!/usr/bin/env zsh

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
