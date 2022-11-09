cat /Library/LaunchDaemons/actions.runner.sebsto-xcodeinstall.plist 
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>actions.runner.sebsto-xcodeinstall.ip-172-31-67-99</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/ec2-user/actions-runner/runsvc.sh</string>
    </array>
    <key>UserName</key>
    <string>ec2-user</string>
    <key>GroupName</key>
    <string>staff</string>  
    <key>WorkingDirectory</key>
    <string>/Users/ec2-user/actions-runner</string>
    <key>RunAtLoad</key>
    <true/>    
    <key>StandardOutPath</key>
    <string>/Users/ec2-user/Library/Logs/actions.runner.sebsto-xcodeinstall.ip-172-31-67-99/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/ec2-user/Library/Logs/actions.runner.sebsto-xcodeinstall.ip-172-31-67-99/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict> 
      <key>ACTIONS_RUNNER_SVC</key>
      <string>1</string>
    </dict>
<!--
    <key>ProcessType</key>
    <string>Interactive</string>
-->
    <key>SessionCreate</key>
    <true/>
  </dict>
</plist>

sudo /bin/launchctl load /Library/LaunchDaemons/actions.runner.sebsto-xcodeinstall.plist