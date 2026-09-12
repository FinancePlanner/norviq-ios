IOS_PROJECT ?= financeplan.xcodeproj
IOS_SCHEME ?= financeplan
IOS_BUILD_DESTINATION ?= generic/platform=iOS Simulator
# No OS pin: xcodebuild resolves against whatever runtime is installed, so this
# does not break on every Xcode update or on a machine with a different one.
IOS_TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17

.PHONY: help sync-brand-assets verify-brand-assets ios-build ios-test ios-ui-test

help:
	@printf "Targets:\n"
	@printf "  make ios-build   Build the iOS app for Simulator\n"
	@printf "  make ios-test    Run unit tests through the shared scheme\n"
	@printf "  make ios-ui-test Run UI tests through the shared scheme\n"
	@printf "  make sync-brand-assets   Regenerate iOS brand assets from StockPlanAssets\n"
	@printf "  make verify-brand-assets Verify generated iOS brand asset dimensions\n"

sync-brand-assets:
	bash scripts/sync-brand-assets.sh

verify-brand-assets:
	bash scripts/verify-brand-assets.sh

ios-build:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_BUILD_DESTINATION)" build

ios-test:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_TEST_DESTINATION)" -only-testing:financeplanTests test

ios-ui-test:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_TEST_DESTINATION)" -only-testing:financeplanUITests test
