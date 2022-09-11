#!/bin/sh -e

echo "🏗 Building a debug build for current machine architecture : $(uname -m)"
swift build --configuration debug

echo "🧪 Running unit tests"
swift test > test.log

if [ $? -eq 0 ]; then
    echo "✅ OK"
else
    echo "🛑 Test failed, check test.log for details"
fi 