#!/bin/bash

set -e

./script/ci/dew_config.sh

source /usr/local/rvm/scripts/rvm
rvm ruby-1.9.2
bundle install

export AWS_DEBUG=1
time script/ci/stresstest.rb cucumber --profile=all
