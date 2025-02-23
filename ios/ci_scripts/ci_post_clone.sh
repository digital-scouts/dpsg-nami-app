#!/bin/sh

# Fail this script if any subcommand fails.
set -e
echo "Running post clone script"

# The default execution directory of this script is the ci_scripts directory.
cd $CI_WORKSPACE # change working directory to the root of your cloned repo.

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
echo "Doing precache"
flutter precache --ios

echo "Installing cocoa pods"
# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

echo "calling pub get"
# Install Flutter dependencies.
flutter pub get

echo "executing pod install"
# Install CocoaPods dependencies.
cd ios && pod install # run `pod install` in the `ios` directory.

exit 0