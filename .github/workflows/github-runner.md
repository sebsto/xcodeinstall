## GitHub Runner as macOS Daemon 

[GitHub instructions to install a runner on macOS](https://docs.github.com/en/actions/hosting-your-own-runners/configuring-the-self-hosted-runner-application-as-a-service) doesn't work on headless machines because it launches as LaunchAgent (these require a GUI Session)

Solution : install as a Launch Dameon

```sh
RUNNER_NAME=actions.runner.xcodeinstall
sudo cp .github/workflows/action-runner.plist /Library/LaunchDaemons/$RUNNER_NAME.plist
sudo chown root:wheel /Library/LaunchDaemons/$RUNNER_NAME.plist 
sudo /bin/launchctl load /Library/LaunchDaemons/$RUNNER_NAME.plist
```