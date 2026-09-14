 
build:
	# use the macos 26 SDK with Swift 6.3.x. Can be remove when switching to Swift 6.4
	SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build
test:
	SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test
clean:
	rm -rf .build

all: clean format build test

format:
	swift format --recursive -i Sources
	swift format --recursive -i Tests
	
test-coverage:
	swift test --enable-code-coverage
	./scripts/ProcessCoverage.swift \
	    `swift test --show-codecov-path` \
	    Tests/coverage.json \
		  Tests/coverage.html \
		  Tests/coverage.svg
