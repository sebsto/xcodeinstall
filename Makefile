 
build:
	swift build
test:
	swift test
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
