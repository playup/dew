#!/bin/bash

echo "Making sure ~/.dew is setup properly..."

# Get the dew config files...
if [ ! -d ~/.dew ]; then
  git clone git@github.com:playup/dew-config.git ~/.dew
fi

pushd ~/.dew
git pull
git submodule init
git submodule update
popd
echo "Finished updating ~/.dew"

