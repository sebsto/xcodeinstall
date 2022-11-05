
# Using xcodeinstall 0.6 
xcodeinstall list -f -s us-east-1 
cat ~/.xcodeinstall/downloadList | jq -c .downloads > available-downloads.json

