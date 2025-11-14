#!/usr/bin/env zsh

SERVICE_USER=lugaru
INSTALLER_WORKING_DIRECTORY="${HOME}/tmp/installers/ruby"
RUBY_BUILD_VERSION="20241030"
RUBY_BUILD_SOURCE_PROJECT="ruby-build-${RUBY_BUILD_VERSION}"
RUBY_BUILD_SOURCE_FILE="v${RUBY_BUILD_VERSION}.tar.gz"
RUBY_BUILD_SOURCE="https://github.com/rbenv/ruby-build/archive/refs/tags/${RUBY_BUILD_SOURCE_FILE}"

DESIRED_RUBY_VERSION="3.3.5"

if [[ "$(whoami)" != "${SERVICE_USER}" ]]; then
  echo "This script must be run by the user '${SERVICE_USER}'. Exiting."
  exit 1
fi

sudo apt install -y libffi-dev libyaml-dev

mkdir -p "${INSTALLER_WORKING_DIRECTORY}"
cd "${INSTALLER_WORKING_DIRECTORY}" || exit

wget "${RUBY_BUILD_SOURCE}"
tar -xvf "${RUBY_BUILD_SOURCE_FILE}"

cd "${RUBY_BUILD_SOURCE_PROJECT}" || exit
PREFIX=/usr/local sudo ./install.sh

sudo ruby-build "${DESIRED_RUBY_VERSION}" /usr/local

ruby -v
which ruby

rm -rf "${INSTALLER_WORKING_DIRECTORY}"
