This is a command line utility to download and install Xcode in headless mode (from a Terminal only).

![swift build workflow](https://github.com/sebsto/xcodeinstall/actions/workflows/swift.yml/badge.svg)

## License

This project is licensed under the Apache 2.0 License. 

[![License][apache-badge]][apache-url]

[apache-badge]: https://img.shields.io/badge/License-Apache%202.0-blue.svg
[apache-url]: LICENSE

## TL;DR

`xcodeinstall` is a command line utility to download and install Xcode from the terminal only. It may work interactively or unattended. In **interactive mode**, it prompts you for your Apple Developer account username, password and MFA code.  In **unattended mode**, it fetches your Apple Developer username and password from AWS Secrets Manager. (Instructions to configure this are below).

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

```
➜  ~ xcodeinstall authenticate -h 

OVERVIEW: Authenticate yourself against Apple Developer Portal

USAGE: xcodeinstall authenticate [--verbose]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -s, --secretmanager-region <secretmanager-region>
                          Instructs to use AWS Secrets Manager to store and read secrets in the given AWS Region  
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
When your Apple Developer Portal crednetials are stored on AWS Secrets Manager, you can just specify the AWS Region 

```
➜  ~ xcodeinstall authenticate -s us-east-1

Retrieving Apple Developer Portal credentials...
Authenticating...
🔐 Two factors authentication is enabled, enter your 2FA code: 00000
✅ Authenticated with MFA.
```

The two above command (interactive and AWS Secrets Manager based) triggers the following prompt on your registered machines (laptop, phone, or tablet)

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
  -s, --secretmanager-region <secretmanager-region>
                          Instructs to use AWS Secrets Manager to store and read secrets in the given AWS Region  
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
  -s, --secretmanager-region <secretmanager-region>
                          Instructs to use AWS Secrets Manager to store and read secrets in the given AWS Region
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

## Minimum IAM Permissions required to use AWS Secrets Manager 

To be authorized to call AWS Secrets Manager from the EC2 instance where you run `xcodeinstall`, create an IAM role that contains the minimum set of permissions to allow `xcodeinstall` to interact with AWS Secrets Manager.

From a machine where the AWS CLI is installed and where you have AWS credentials to create roles and permissions, type the following commands :


1. First create a role that can be attached (trusted) by any EC2 instances:

```zsh
# Create the trust policy file 
cat << EOF > ec2-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "ec2.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role itself (with no permission at the moment)
aws iam create-role \
    --role-name xcodeinstall \
    --assume-role-policy-document file://ec2-role-trust-policy.json
```

2. Second, create a policy that contains the minimum set of permissions to interact with AWS Secrets Manager 

```zsh 
# Create the policy file with the set of permissions
# CHANGE 000000000000 with your AWS Account ID
cat << EOF > ec2-policy.json 
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "xcodeinstall",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:GetSecretValue",
                "secretsmanager:PutSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:*:000000000000:secret:xcodeinstall-*"
        }
    ]
}
EOF

# Create the policy 
aws iam create-policy                      \
    --policy-name xcodeinstall-permissions \
    --policy-document file://ec2-policy.json
```

3. Third, attach the policy to the role 

```zsh
# Attach a policy to a role 
# CHANGE 000000000000 with your AWS Account ID
aws iam attach-role-policy                                            \
     --policy-arn arn:aws:iam::000000000000:policy/xcodeinstall-permissions    \
     --role-name xcodeinstall
```

4. Fourth, attach the role to your EC2 Mac instance (through an instance profile)

```zsh
# Create an instance profile 
aws iam create-instance-profile                   \
     --instance-profile-name xcodeinstall-profile

# Attach the role to the profile
aws iam add-role-to-instance-profile             \
    --instance-profile-name xcodeinstall-profile \
    --role-name xcodeinstall   

# Identify the Instance ID of your EC2 Mac Instance.
# You may use the AWS Console or search by tags like this (replace the tag value with yours)
INSTANCE_ID=$(aws ec2 describe-instances                                                 \
               --filter "Name=tag:Name,Values=M1 Monterey"                            \
               --query "Reservations[].Instances[?State.Name == 'running'].InstanceId[]" \
               --output text)

# verify you have an ID (you may add --region to target the correct AWS Region)
echo $INSTANCE_ID

# Associate the profile to the instance 
aws ec2 associate-iam-instance-profile \
    --instance-id $INSTANCE_ID         \
    --iam-instance-profile Name="xcodeinstall-profile"
```

When you start other EC2 Mac instance, you just need to attach the profile to the new instance.  The Policy and Role can be reused for multiple EC2 instances.

## How to store your secrets on AWS Secrets Manager

When using AWS Secrets Manager to retrieve your Apple Developer Portal username and password, you have to prepare an AWS Secrets Manager secret as following:

- secret name : `xcodeinstall-apple-credentials`
- secret format : a JSON string similar to this one :

```json
{"username":"your_username","password":"your_password"}
```

To help you to create this secret, you may use the following command: (Be sure to adjust the name of the AWS Region to your requirements. Using an AWS Region geographically close to you helps to reduce latency)

```zsh
➜  ~ xcodeinstall storesecrets -s us-east-1
```

## How to contribute 

I welcome all type of contributions, not only code : testing and creating bug report, documentation, tutorial etc...
If you are not sure how to get started or how to be useful, contact me at stormacq@amazon.com

I listed a couple of ideas below.

## List of ideas 

- add a CloudWatch Log backend to Logging framework 
- add possibility to emit SNS notifications on error, such as Session Expired  
- add support to install with homebrew