format:
	swift format --recursive -i Sources/* 
	swift format --recursive -i Tests/*  
build:
	swift build
test:
	swift test
clean:
	rm -rf .build

all: clean format build test
