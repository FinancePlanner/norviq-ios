IOS_PROJECT ?= financeplan.xcodeproj
IOS_SCHEME ?= financeplan
IOS_BUILD_DESTINATION ?= generic/platform=iOS Simulator
# No OS pin: xcodebuild resolves against whatever runtime is installed, so this
# does not break on every Xcode update or on a machine with a different one.
IOS_TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17
SHARED_PACKAGE ?= Packages/StockPlanShared

.PHONY: help sync-brand-assets verify-brand-assets check-pnl-colors ios-build ios-test ios-ui-test shared-test shared-format shared-format-lint

help:
	@printf "Targets:\n"
	@printf "  make ios-build   Build the iOS app for Simulator\n"
	@printf "  make ios-test    Run unit tests through the shared scheme\n"
	@printf "  make ios-ui-test Run UI tests through the shared scheme\n"
	@printf "  make shared-test        Run the StockPlanShared package tests (swift test)\n"
	@printf "  make shared-format      Format StockPlanShared with its own .swiftformat\n"
	@printf "  make shared-format-lint Check StockPlanShared formatting without rewriting\n"
	@printf "  make sync-brand-assets   Regenerate iOS brand assets from StockPlanAssets\n"
	@printf "  make verify-brand-assets Verify generated iOS brand asset dimensions\n"
	@printf "  make check-pnl-colors    Fail on raw .green/.red (use AppTheme gain/loss)\n"

sync-brand-assets:
	bash scripts/sync-brand-assets.sh

verify-brand-assets:
	bash scripts/verify-brand-assets.sh

check-pnl-colors:
	bash scripts/check-raw-pnl-colors.sh

ios-build: check-pnl-colors
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_BUILD_DESTINATION)" build

ios-test: check-pnl-colors
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_TEST_DESTINATION)" -only-testing:financeplanTests test

ios-ui-test:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_TEST_DESTINATION)" -only-testing:financeplanUITests test

shared-test:
	swift test --package-path "$(SHARED_PACKAGE)"

# --config keeps the app's root .swiftformat (2-space indent, other wrapping)
# from being merged into the package's own 4-space style.
shared-format:
	swiftformat --config "$(SHARED_PACKAGE)/.swiftformat" "$(SHARED_PACKAGE)"

shared-format-lint:
	swiftformat --lint --config "$(SHARED_PACKAGE)/.swiftformat" "$(SHARED_PACKAGE)"
