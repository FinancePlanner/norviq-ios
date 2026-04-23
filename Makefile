IOS_PROJECT ?= financeplan.xcodeproj
IOS_SCHEME ?= Norviqa TestFlight Dev
IOS_BUILD_DESTINATION ?= generic/platform=iOS Simulator
IOS_TEST_DESTINATION ?= platform=iOS Simulator,name=iPhone 17,OS=26.4

.PHONY: help ios-build ios-test ios-ui-test

help:
	@printf "Targets:\n"
	@printf "  make ios-build   Build the iOS app for Simulator\n"
	@printf "  make ios-test    Run unit tests through the shared scheme\n"
	@printf "  make ios-ui-test Run UI tests through the shared scheme\n"

ios-build:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_BUILD_DESTINATION)" build

ios-test:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_TEST_DESTINATION)" -only-testing:financeplanTests test

ios-ui-test:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination "$(IOS_TEST_DESTINATION)" -only-testing:financeplanUITests test
