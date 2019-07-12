#!/usr/bin/env bash

# we need to disable sparkle for test at travis-ci.
# if not, test app will stuck with message like below:
# "Insecure update error! For security reasons, you need to sign your updates
# with a DSA key. See Sparkle's documentation for more information."

set -x
set -e

base_dir="$(cd $(dirname $0);pwd)"
storyboard_file="${base_dir}/../Hakumai/Storyboards/MainWindowController.storyboard"
sparkle_object="SUUpdater"

# http://stackoverflow.com/questions/5410757/delete-a-line-containing-a-specific-string-using-sed#comment28307642_5410784
sed -i '' "/${sparkle_object}/d" ${storyboard_file}
