#!/usr/bin/env zsh

#looi1 (by Zue)

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

  conda config --set channel_priority strict
}