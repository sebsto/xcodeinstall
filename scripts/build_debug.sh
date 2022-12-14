#!/bin/sh -e

echo "๐ Building a debug build for current machine architecture : $(uname -m)"
swift build --configuration debug

echo "๐งช Running unit tests"
swift test > test.log

if [ $? -eq 0 ]; then
    echo "โ OK"
else
    echo "๐ Test failed, check test.log for details"
fi 