#!/bin/bash

if [ "${1}" ]; then
  cucumber_profile="${1}"
else
  cucumber_profile="default"
fi

set -e

./script/ci/dew_config.sh

source /usr/local/rvm/scripts/rvm
rvm ruby-1.9.2
bundle install

export AWS_DEBUG=1
time bundle exec rake spec:covered
time bundle exec cucumber --profile=${cucumber_profile}
