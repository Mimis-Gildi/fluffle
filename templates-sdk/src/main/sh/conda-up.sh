#!/usr/bin/env zsh

cat <<EOF
IMPORTANT!:
  conda setup is particular to the agent user only!

WARNING!:
  this installation process is INTERACTIVE!


EOF

INSTALLER_WORKING_DIRECTORY="${HOME}/tmp/installers/miniforge"
FORGE_VERSION="Miniforge3"
FORGE_PRODUCT="$FORGE_VERSION-$(uname)-$(uname -m)"
FORGE_SCRIPT="$FORGE_PRODUCT.sh"
FORGE_ARTIFACT="https://github.com/conda-forge/miniforge/releases/latest/download/$FORGE_SCRIPT"

mkdir -p "${INSTALLER_WORKING_DIRECTORY}"
cd "${INSTALLER_WORKING_DIRECTORY}" || exit

curl -L -O "$FORGE_ARTIFACT"
chmod +x "$FORGE_SCRIPT"
ls -lha .

./"$FORGE_SCRIPT"

