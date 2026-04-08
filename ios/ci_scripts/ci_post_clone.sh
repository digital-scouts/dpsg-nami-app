#!/bin/sh

set -e

FLUTTER_VERSION="3.38.4"
FLUTTER_ARCHIVE="flutter_macos_${FLUTTER_VERSION}-stable.zip"
COCOAPODS_VERSION="1.16.2"

install_cocoapods() {
	echo "Installing CocoaPods ${COCOAPODS_VERSION} via RubyGems"
	export GEM_HOME="$HOME/.gem"
	export PATH="$GEM_HOME/bin:$PATH"
	gem install cocoapods -v "$COCOAPODS_VERSION" --no-document
	pod --version
}

pod_install_with_retry() {
	attempt=1
	max_attempts=3

	while [ "$attempt" -le "$max_attempts" ]; do
		echo "Running pod install (attempt ${attempt}/${max_attempts})"
		if (
			cd ios
			pod install --deployment --verbose
		); then
			return 0
		fi

		if [ "$attempt" -lt "$max_attempts" ]; then
			echo "pod install failed, clearing CocoaPods trunk cache before retry"
			rm -rf "$HOME/.cocoapods/repos/trunk"
		fi

		attempt=$((attempt + 1))
	done

	echo "pod install failed after ${max_attempts} attempts"
	return 1
}

echo "Running post clone script"

# The default execution directory of this script is the ci_scripts directory.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Downloading Flutter ${FLUTTER_VERSION}..."
curl -sLO "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/${FLUTTER_ARCHIVE}"
echo "Extracting Flutter..."
unzip -qq "$FLUTTER_ARCHIVE" -d "$HOME"
export PATH="$PATH:$HOME/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Doing precache"
flutter precache --ios

echo "Running flutter doctor"
flutter doctor -v

install_cocoapods

echo "Calling flutter pub get"
flutter pub get

pod_install_with_retry

echo "Cleaning up..."
rm -f "$CI_PRIMARY_REPOSITORY_PATH/${FLUTTER_ARCHIVE}"

exit 0