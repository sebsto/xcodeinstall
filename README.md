This is a command line utility to download and install Xcode in headless mode (from a Terminal only).

It works either interactively or unattended. In **interactive mode**, it prompts you for your Apple Developer account username, password and MFA code.  In **unattended mode**, it fetches your Apple Developer username and password from AWS Secrets Manager. (Instructions to configure this are below).

When **MFA is configured** (which we highly recommend), a human interaction is required to enter the MFA code sent to your device.  This step cannot be automated.

The username and password ARE NOT STORED on the local volume. They are used to interact with Apple's Developer Portal API and collect a session token.  The session token is stored in `$HOME/.xcodeinstall` or on AWS Secrets Manager.

The session stays valid for several days, sometimes weeks before it expires.  When the session expires, you have to authenticate again. Apple typically prompt you for a new authentication when connecting from a new IP address or location (switching between laptop and EC2 instance for example)

## Demo 

![Video Demo](img/xcodeinstall-demo.gif)

## Why install Xcode in headless mode?

When preparing a macOS machine in the cloud for CI/CD, you don't always have access to the login screen, or you don't want to access it.

It is a best practice to automate the preparation of your build environment to ensure they are always identical.

## How to install 

When finished, I would like to distribute this tool with homebrew.  Installation will look like the below.

(not implemented yet)

`brew add tap sebsto/sebsto`

`brew install xcodeinstall`

## How to use 

### Overview 

```
➜  ~ xcodeinstall

OVERVIEW: A utility to download and install Xcode

USAGE: xcodeinstall [--verbose] <subcommand>

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  authenticate            Authenticate yourself against Apple Developer Portal
  signout                 Signout from Apple Developer Portal
  list                    List available versions of Xcode and development tools
  download                Download the specified version of Xcode
  install                 Install a specific XCode version or addon package

  See 'xcodeinstall help <subcommand>' for detailed help.
```

### Authentication 

Storing username, password, and session token in AWS Secrets Manager is not implemented yet

```
➜  ~ xcodeinstall authenticate -h 

OVERVIEW: Authenticate yourself against Apple Developer Portal

USAGE: xcodeinstall authenticate [--verbose]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  --version               Show the version.
  -h, --help              Show help information.
```

Interactive authentication 

```
➜  ~ xcodeinstall authenticate    

⚠️⚠️⚠️
This tool prompts you for your Apple ID username, password, and two factors authentication code.
These values are not stored anywhere. They are used to get an Apple session ID.

The Session ID is securely stored on your AWS Account, using AWS Secrets Manager.
The AWS Secrets Manager secret name is "xcodeinstall_session"

⌨️  Enter your Apple ID username: <your apple id email>
⌨️  Enter your Apple ID password: 
Authenticating...
🔐 Two factors authentication is enabled, enter your 2FA code: 000000
✅ Authenticated with MFA.
```

The above triggers the following prompt on your registered machines (laptop, phone, or tablet)

![Apple MFA Authorization](img/mfa-01.png)

![Apple MFA code](img/mfa-02.png)

### List files available to download 

```
➜  ~ xcodeinstall list -h
OVERVIEW: List available versions of Xcode and development tools

USAGE: xcodeinstall list [--verbose] [--force] [--only-xcode] [--xcode-version <xcode-version>] [--most-recent-first] [--date-published]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -f, --force             Force to download the list from Apple Developer Portal, even if we have it in the cache
  -o, --only-xcode        Filter on Xcode package only
  -x, --xcode-version <xcode-version>
                          Filter on provided Xcode version number (default: 13)
  -m, --most-recent-first Sort by most recent releases first
  -d, --date-published    Show publication date
  --version               Show the version.
  -h, --help              Show help information.
  ```

### Download file 

```
➜  ~ xcodeinstall download -h
OVERVIEW: Download the specified version of Xcode

USAGE: xcodeinstall download [--verbose] [--force] [--only-xcode] [--xcode-version <xcode-version>] [--most-recent-first] [--date-published] [--name <name>]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -f, --force             Force to download the list from Apple Developer Portal, even if we have it in the cache
  -o, --only-xcode        Filter on Xcode package only
  -x, --xcode-version <xcode-version>
                          Filter on provided Xcode version number (default: 13)
  -m, --most-recent-first Sort by most recent releases first
  -d, --date-published    Show publication date
  -n, --name <name>       The exact package name to downloads. When omited, it asks interactively
  --version               Show the version.
  -h, --help              Show help information.
  ```

  When you known the name of the file (for example `Xcode 13.4.1.xip`), you can use the `--name` option, otherwise it prompts your for the file name.

  ```
  xcodeinstall download --name "Xcode 13.4.1.xip"
  ```

### Install file 

This tool call `sudo` to install packages.  Be sure your userid has a a `sudoers` file configured to not prompt for a password.

```
➜  ~ cat /etc/sudoers.d/your_user_id 
# Give your_user_id sudo access
your_user_id ALL=(ALL) NOPASSWD:ALL
```

```
➜  ~ xcodeinstall install -h 
OVERVIEW: Install a specific XCode version or addon package

USAGE: xcodeinstall install [--verbose] [--name <name>]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -n, --name <name>       The exact package name to install. When omited, it asks interactively
  --version               Show the version.
  -h, --help              Show help information.
```

When you known the name of the file (for example `Xcode 13.4.1.xip`), you can use the `--name` option, otherwise it prompts your for the file name.

  ```
  xcodeinstall install --name "Xcode 13.4.1.xip"
  ```

## How to store your secrets on AWS Secrets Manager

to be implemented 

## How to contribute 

I welcome all type of contributions, not only code : testing and creating bug report, documentation, tutorial etc...
If you are not sure how to get started or how to be useful, contact me at stormacq@amazon.com

I listed a couple of ideas below.

## List of ideas 

- add possibility to retrieve username and password from AWS Secrets Manager 
- add possibility to store session cookies to AWS Secrets Manager 
- add a CloudWatch Log backend to Logging framework 
- add possibility to emit SNS notifications on error, such as Session Expired  
- add support to install with homebrew