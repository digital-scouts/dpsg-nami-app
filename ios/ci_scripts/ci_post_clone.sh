#!/bin/sh

set -e

FLUTTER_VERSION="3.38.4"
FLUTTER_ARCHIVE="flutter_macos_${FLUTTER_VERSION}-stable.zip"
COCOAPODS_VERSION="1.16.2"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)}"

ensure_flutter() {
	if command -v flutter >/dev/null 2>&1; then
		echo "Using local Flutter $(flutter --version | head -n 1)"
		return 0
	fi

	echo "Downloading Flutter ${FLUTTER_VERSION}..."
	curl -sLO "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/${FLUTTER_ARCHIVE}"
	echo "Extracting Flutter..."
	unzip -qq "$FLUTTER_ARCHIVE" -d "$HOME"
	export PATH="$PATH:$HOME/flutter/bin"
}

install_cocoapods() {
	if command -v pod >/dev/null 2>&1; then
		echo "Using preinstalled CocoaPods $(pod --version)"
		return 0
	fi

	echo "Installing CocoaPods ${COCOAPODS_VERSION} via Homebrew"
	export HOMEBREW_NO_AUTO_UPDATE=1
	brew install cocoapods
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

echo "Using repository root: $REPO_ROOT"
cd "$REPO_ROOT"

ensure_flutter

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
rm -f "$REPO_ROOT/${FLUTTER_ARCHIVE}"

exit 0