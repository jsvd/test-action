#!/bin/sh

set -e

sh -c "ls -lha"
sh -c "bin/ruby /action.rb $*"
