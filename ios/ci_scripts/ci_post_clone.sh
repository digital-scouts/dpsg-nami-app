#!/bin/sh

# Fail this script if any subcommand fails.
set -e
echo "Running post clone script"

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

# Install Flutter using curl.
echo "Downloading Flutter 3.32.5..."
curl -sLO "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.32.5-stable.zip"
echo "Extracting Flutter..."
unzip -qq flutter_macos_3.32.5-stable.zip -d $HOME
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter installation
echo "Flutter version:"
flutter --version

# Install Flutter artifacts for iOS (--ios), or macOS (--macos) platforms.
echo "Doing precache"
flutter precache --ios

# Check Flutter setup
echo "Running flutter doctor"
flutter doctor -v

echo "Installing cocoa pods"
# Install CocoaPods using Homebrew.
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

echo "calling pub get"
echo "Aktuelles Verzeichnis: $(pwd)"
# Install Flutter dependencies.
flutter pub get

echo "executing pod install"
# Install CocoaPods dependencies.
cd ios && pod install # run `pod install` in the `ios` directory.

# Cleanup downloaded Flutter archive
echo "Cleaning up..."
rm -f $CI_PRIMARY_REPOSITORY_PATH/flutter_macos_3.32.5-stable.zip

exit 0