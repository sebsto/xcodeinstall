[![Build & Test on EC2](https://github.com/sebsto/xcodeinstall/actions/workflows/build_and_test.yml/badge.svg)](https://github.com/sebsto/xcodeinstall/actions/workflows/build_and_test.yml)

[![Build & Test on GitHub](https://github.com/sebsto/xcodeinstall/actions/workflows/build_and_test_gh_hosted.yml/badge.svg)](https://github.com/sebsto/xcodeinstall/actions/workflows/build_and_test_gh_hosted.yml)

![Test coverage](https://raw.githubusercontent.com/sebsto/xcodeinstall/refs/heads/main/Tests/coverage.svg)

![language](https://img.shields.io/badge/swift-6.2-blue)
![platform](https://img.shields.io/badge/platform-macOS-green)
[![license](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

A command line utility to download and install Xcode in headless mode — designed for preparing EC2 Mac AMIs with AWS Parameter Store integration.

## TL;DR

![Download](img/download.png)
![Install](img/install.png)

## What is it

`xcodeinstall` is a command line utility to download and install Xcode from the terminal only. It works both interactively and unattended:

- **Interactive mode**: Prompts you for your Apple Developer account username, password, and MFA code
- **Unattended mode**: Fetches your Apple Developer credentials from AWS Parameter Store

### Key Features

✅ **AMI Automation Ready**: Fully scriptable for Packer, Ansible, or shell-based image builds  
✅ **AWS Parameter Store Integration**: Centralized credentials and shared session tokens across your fleet, at no storage cost  
✅ **Multi-Machine Support**: Authenticate once on your laptop, use the session on all EC2 instances  
✅ **Multi-Version Management**: Install multiple Xcode versions side-by-side and switch between them  
✅ **Automated Downloads**: Download any Xcode version from Apple Developer Portal  
✅ **Headless Installation**: Install Xcode without GUI interaction  
✅ **MFA Support**: Works with Apple's two-factor authentication (requires manual code entry)  
✅ **Persistent Configuration**: Automatically saves AWS region and profile settings after first use  

## Demo 

![Video Demo](img/xcodeinstall-demo.gif)

## Why install Xcode in headless mode?

When preparing a macOS machine in the cloud for CI/CD, you don't always have access to the login screen, or you don't want to access it.

It is a best practice to automate the preparation of your build environment to ensure they are always identical.

## Built for EC2 Mac AMI Preparation

Unlike other Xcode management tools designed for local development, `xcodeinstall` is purpose-built for **automating EC2 Mac AMI creation** — the step where you bake Xcode into a golden image that your build fleet launches from.

**The problem:** Preparing an EC2 Mac AMI with Xcode requires downloading and installing from Apple Developer Portal without GUI access. Authentication requires credentials and MFA codes, session tokens expire unpredictably, and you want the process fully automated in your image pipeline.

**How `xcodeinstall` solves it:**

1. **Centralized credentials with AWS Parameter Store** — Store your Apple Developer credentials once, access them from any EC2 Mac instance during AMI builds. No SSH-ing into machines to paste passwords.

2. **Shared session tokens** — Authenticate on your laptop (where you can receive the MFA code), then your Packer or Ansible image build uses that session via Parameter Store.

3. **IAM-based access control** — No API keys or config files baked into the image. Attach an IAM role to the builder instance and `xcodeinstall` authenticates to Parameter Store automatically via the instance profile.

4. **Fully scriptable** — Every command works non-interactively with `--name` flags, integrating cleanly into Packer provisioners, Ansible playbooks, or EC2 Image Builder components.

**Typical AMI build workflow:**

```bash
# One-time setup (from your laptop, where you can receive MFA)
xcodeinstall storesecrets -s us-west-2 -p myprofile
xcodeinstall authenticate -s us-west-2 -p myprofile
# Enter MFA code when prompted

# In your Packer provisioner / Ansible playbook (IAM role attached, no flags needed)
xcodeinstall download --name "Xcode_26.5_Apple_silicon.xip"
xcodeinstall install --name "Xcode_26.5_Apple_silicon.xip"
```

No credentials on disk, no interactive prompts during the image build, reproducible golden images every time.

## How to install 

Most of you are not interest by the source code. To install the brinary, use [homebrew](https://brew.sh) package manager and install a custom tap, then install the package. 

First, install the custom tap. This is a one-time operation.

```zsh
➜  ~ brew tap sebsto/macos

==> Tapping sebsto/macos
Cloning into '/opt/homebrew/Library/Taps/sebsto/homebrew-macos'...
remote: Enumerating objects: 6, done.
remote: Counting objects: 100% (6/6), done.
remote: Compressing objects: 100% (5/5), done.
remote: Total 6 (delta 0), reused 0 (delta 0), pack-reused 0
Receiving objects: 100% (6/6), 5.55 KiB | 5.55 MiB/s, done.
Tapped 1 formula (13 files, 21.7KB).
```

Once the tap is added, install the package by typing `brew install xcodeinstall`

```zsh
➜  ~ brew install xcodeinstall 

==> Downloading https://github.com/sebsto/xcodeinstall/archive/refs/tags/v0.1.tar.gz
Already downloaded: /Users/stormacq/Library/Caches/Homebrew/downloads/03a2cadcdf453516415f70a35b054cdcfb33bd3a2578ab43f8b07850b49eb19c--xcodeinstall-0.1.tar.gz
==> Installing xcodeinstall from sebsto/macos
🍺  /opt/homebrew/Cellar/xcodeinstall/0.2: 8 files, 25.6MB, built in 2 seconds
==> Running `brew cleanup xcodeinstall`...
```

Once installed, it is in the path, you can just type `xcodeinstall` to start the tool.

## How to use

### Quick Start for First-Time Users

The typical workflow is:

1. **Authenticate** - Sign in to Apple Developer Portal (one time)
2. **List** - Browse available Xcode versions
3. **Download** - Download your desired Xcode version
4. **Install** - Install the downloaded Xcode (versioned, with symlink)
5. **Switch** - Switch between installed versions

```bash
# Step 1: Authenticate (prompts for Apple ID and password)
xcodeinstall authenticate

# Step 2: List available Xcode versions
xcodeinstall list --only-xcode

# Step 3: Download a specific version (prompts if --name is omitted)
xcodeinstall download --name "Xcode_26.5_Apple_silicon.xip"

# Step 4: Install the downloaded version (installs as Xcode-26.5.app)
xcodeinstall install --name "Xcode_26.5_Apple_silicon.xip"

# Step 5: Switch between installed versions
xcodeinstall switch 26.4
```

**Using AWS Parameter Store?** Add `-s <region>` and `-p <profile>` flags to the authenticate command. These settings are **automatically saved** and reused for subsequent commands. See [AWS Parameter Store](#using-aws-parameter-store) section below.

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
  switch                  Switch the active Xcode version
  storesecrets            Store Apple Developer credentials in AWS Parameter Store

  See 'xcodeinstall help <subcommand>' for detailed help.
```

### Persistent Configuration

When using AWS Parameter Store, `xcodeinstall` **automatically saves** your `-s` (AWS region) and `-p` (AWS profile) settings to `~/.xcodeinstall/config.json`.

**First time:** Specify the options explicitly:
```bash
xcodeinstall authenticate -s us-west-2 -p myprofile
```

**Subsequent commands:** Options are loaded automatically:
```bash
xcodeinstall list
# Info: Using saved settings: -s us-west-2 -p myprofile
```

**Override saved settings:** Command-line arguments always take precedence:
```bash
xcodeinstall list -s us-east-1
# Info: Using saved settings: -p myprofile
# Uses: us-east-1 (overridden) + myprofile (saved)
```

**Partial updates:** Specifying only one option preserves the other:
```bash
xcodeinstall authenticate -p newprofile
# Keeps saved region, updates profile
```

This eliminates repetitive typing of `-s` and `-p` flags while maintaining full control through command-line overrides.

### Authentication

```
➜  ~ xcodeinstall authenticate -h

OVERVIEW: Authenticate yourself against Apple Developer Portal

USAGE: xcodeinstall authenticate [--verbose] [-s <region>] [-p <profile>]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -s, --secret-region <secret-region>
                          Instructs to store and read secrets on AWS in the given AWS Region
  -p, --profile <profile> The AWS profile name to use for authentication (from ~/.aws/credentials and ~/.aws/config)
  --version               Show the version.
  -h, --help              Show help information.
```

#### Interactive Authentication (Local Storage)

For local development or testing, authenticate without AWS Parameter Store:

```bash
➜  ~ xcodeinstall authenticate

⚠️⚠️⚠️
This tool prompts you for your Apple ID username, password, and two factors authentication code.
These values are not stored anywhere. They are used to get an Apple session ID.

The Session ID is stored locally in ~/.xcodeinstall/

⌨️  Enter your Apple ID username: <your apple id email>
⌨️  Enter your Apple ID password:
Authenticating...
🔐 Two factors authentication is enabled, enter your 2FA code: 000000
✅ Authenticated with MFA.
```

#### Using AWS Parameter Store

> ### ⚠️ Migrating from AWS Secrets Manager
>
> Earlier versions of `xcodeinstall` stored secrets in AWS Secrets Manager. This is a **breaking change** and needs three things from you.
>
> **1. Update your IAM policy.** The permissions changed from `secretsmanager:*` to `ssm:PutParameter` and `ssm:GetParameter`. See [Minimum IAM Permissions](#minimum-iam-permissions-required-to-use-aws-parameter-store). Nothing works until the policy is updated.
>
> **2. Re-create your secrets.** Nothing migrates automatically. Re-run `storesecrets` and `authenticate`, then delete the old secrets so they stop costing $0.40/month each:
>
> ```bash
> aws secretsmanager delete-secret --secret-id xcodeinstall-apple-credentials --force-delete-without-recovery
> aws secretsmanager delete-secret --secret-id xcodeinstall-apple-session-token --force-delete-without-recovery
> ```
>
> **3. Rename the flag in your scripts.** `--secretmanager-region` is now `--secret-region`. The short form `-s` is unchanged, so `-s <region>` keeps working and only the long form needs updating.
>
> Also note that `~/.xcodeinstall/config.json` uses a new key name for the region, so your saved region is dropped on first run after upgrading. The next command that passes `-s` saves it again. Your saved `-p` profile is unaffected.

For production, CI/CD, or multi-machine setups, use AWS Parameter Store to store credentials and session tokens securely:

```bash
➜  ~ xcodeinstall authenticate -s us-west-2 -p myprofile

Retrieving Apple Developer Portal credentials...
Authenticating...
🔐 Two factors authentication is enabled, enter your 2FA code: 000000
✅ Authenticated with MFA.
```

**Authentication Flow:**
1. When **MFA is configured** on your Apple Developer account (highly recommended), you must manually enter the MFA code sent to your device. This step cannot be automated for security reasons.

![Apple MFA Authorization](img/mfa-01.png)

![Apple MFA code](img/mfa-02.png)

2. Your Apple Developer Portal **username and password are NEVER stored** on disk. They are only used to authenticate with Apple's API and obtain a session token. When using AWS Parameter Store, **your username and password are stored as an encrypted `SecureString` parameter**.

3. The **session token is stored** either locally in `~/.xcodeinstall/` or on AWS Parameter Store (your choice).

4. Sessions typically remain valid for several days or weeks. When expired, re-authentication is required. Apple may also prompt for re-authentication when connecting from a new IP address or location.

**AWS Parameter Store Benefits:**
- **Secure storage**: Credentials and session tokens stored in AWS cloud as encrypted `SecureString` parameters
- **Multi-machine access**: Authenticate on your laptop, use the session on EC2 instances
- **Automatic configuration**: Region and profile settings saved after first use
- **No storage cost**: Standard-tier parameters are free, and they are encrypted with the account's default `aws/ssm` KMS key at no extra charge

**Important:** The `-s` (region) and `-p` (profile) options are **automatically saved** to `~/.xcodeinstall/config.json` for subsequent commands. You only need to specify them once.

> **Note:** When using Parameter Store, you must use the **same AWS region and profile** for all commands (`authenticate`, `list`, `download`). The saved configuration ensures consistency across commands.

### List Files Available to Download

```bash
➜  ~ xcodeinstall list -h
OVERVIEW: List available versions of Xcode and development tools

USAGE: xcodeinstall list [--verbose] [--force] [--only-xcode] [--xcode-version <xcode-version>] [--most-recent-first] [--date-published] [-s <region>] [-p <profile>]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -f, --force             Force to download the list from Apple Developer Portal, even if we have it in the cache
  -o, --only-xcode        Filter on Xcode package only
  -x, --xcode-version <xcode-version>
                          Filter on provided Xcode version number (default: 13)
  -m, --most-recent-first Sort by most recent releases first
  -d, --date-published    Show publication date
  -s, --secret-region <secret-region>
                          Instructs to store and read secrets on AWS in the given AWS Region
  -p, --profile <profile> The AWS profile name to use for authentication
  --version               Show the version.
  -h, --help              Show help information.
```

**Examples:**

```bash
# List all available downloads
xcodeinstall list

# List only Xcode packages, most recent first
xcodeinstall list --only-xcode --most-recent-first

# Filter by Xcode version 15
xcodeinstall list --only-xcode --xcode-version 15

# With AWS Parameter Store (uses saved settings if available)
xcodeinstall list
# Info: Using saved settings: -s us-west-2 -p myprofile
```

### Download File

```bash
➜  ~ xcodeinstall download -h
OVERVIEW: Download the specified version of Xcode

USAGE: xcodeinstall download [--verbose] [--force] [--only-xcode] [--xcode-version <xcode-version>] [--most-recent-first] [--date-published] [--name <name>] [-s <region>] [-p <profile>]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -f, --force             Force to download the list from Apple Developer Portal, even if we have it in the cache
  -o, --only-xcode        Filter on Xcode package only
  -x, --xcode-version <xcode-version>
                          Filter on provided Xcode version number (default: 13)
  -m, --most-recent-first Sort by most recent releases first
  -d, --date-published    Show publication date
  -n, --name <name>       The exact package name to download. When omitted, it prompts interactively
  -s, --secret-region <secret-region>
                          Instructs to store and read secrets on AWS in the given AWS Region
  -p, --profile <profile> The AWS profile name to use for authentication
  --version               Show the version.
  -h, --help              Show help information.
```

**Examples:**

```bash
# Interactive mode - prompts for file selection
xcodeinstall download --only-xcode

# Specify exact file name (useful for automation)
xcodeinstall download --name "Xcode 15.2.xip"

# With AWS Parameter Store (uses saved settings if available)
xcodeinstall download --name "Xcode 15.2.xip"
# Info: Using saved settings: -s us-west-2 -p myprofile
```

Downloads are stored in `~/.xcodeinstall/download/`

### Install File

This command uses `sudo` to install packages and run `xcode-select`. For unattended installations, configure your user account to run `sudo` without a password prompt:

```bash
# Create a sudoers file for your user
➜  ~ cat /etc/sudoers.d/your_user_id
# Give your_user_id sudo access
your_user_id ALL=(ALL) NOPASSWD:ALL
```

**Command Help:**

```bash
➜  ~ xcodeinstall install -h
OVERVIEW: Install a specific XCode version or addon package

USAGE: xcodeinstall install [--verbose] [--name <name>] [--xcode-version <xcode-version>]

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  -n, --name <name>       The exact package name to install. When omitted, it prompts interactively
  --xcode-version <xcode-version>
                          Override the Xcode version identifier (e.g., '26.5'). Auto-detected from
                          filename if omitted.
  --version               Show the version.
  -h, --help              Show help information.
```

**Examples:**

```bash
# Interactive mode - lists downloaded files and prompts for selection
xcodeinstall install

# Specify exact file name (useful for automation)
xcodeinstall install --name "Xcode_26.5_Apple_silicon.xip"

# Override the version identifier
xcodeinstall install --name "Xcode_26.5.xip" --xcode-version "26.5-custom"
```

The installation process:
1. Extracts the `.xip` file (this takes several minutes)
2. Moves to `/Applications/Xcode-{version}.app` (version auto-detected from filename)
3. Installs additional system packages
4. Creates a symlink `/Applications/Xcode.app` pointing to the newly installed version
5. Runs `xcode-select -s` to activate the new version

Architecture suffixes like "Apple silicon" or "Universal" are automatically stripped from the version identifier.

### Multi-Version Management

`xcodeinstall` supports installing multiple Xcode versions side-by-side and switching between them.

After installing multiple versions, your `/Applications` directory looks like:

```
/Applications/Xcode-26.4.app
/Applications/Xcode-26.5.app
/Applications/Xcode.app -> Xcode-26.5.app    (symlink to active version)
```

#### Switching Versions

Use the `switch` subcommand to change the active Xcode version:

```bash
➜  ~ xcodeinstall switch -h
OVERVIEW: Switch the active Xcode version (requires sudo for xcode-select)

USAGE: xcodeinstall switch [--verbose] [<version>]

ARGUMENTS:
  <version>               The Xcode version to activate (e.g., '26.5'). When omitted, it asks
                          interactively.

OPTIONS:
  -v, --verbose           Produce verbose output for debugging
  --version               Show the version.
  -h, --help              Show help information.
```

**Examples:**

```bash
# Interactive mode - lists installed versions and prompts for selection
xcodeinstall switch

# Switch directly to a specific version
xcodeinstall switch 26.5
```

Switching updates both the `/Applications/Xcode.app` symlink and runs `sudo xcode-select -s` to register the change system-wide.

#### Safety

- If `/Applications/Xcode.app` already exists as a real directory (not a symlink), the tool will refuse to overwrite it and ask you to rename or remove it first.
- Existing versioned installations are never modified when installing a new version.

## Minimum IAM Permissions required to use AWS Parameter Store

The minimum IAM permisions required to use this tool with AWS Parameter Store is as below (do not forget to replace 000000000000 with your AWS Account ID)

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "xcodeinstall",
            "Effect": "Allow",
            "Action": [
                "ssm:PutParameter",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:000000000000:parameter/xcodeinstall/*"
        }
    ]
}
```

No `kms:*` permission is required. `xcodeinstall` stores its parameters as `SecureString`, encrypted with your account's default `aws/ssm` AWS managed key, which every principal in the account may use through Systems Manager. If you prefer a customer managed KMS key, add `kms:Encrypt` and `kms:Decrypt` for that key (`kms:GenerateDataKey` instead of `kms:Encrypt` if the parameter is promoted to the advanced tier).

Once associated with an IAM Role, you can attach the role to any IAM principal : user, group or an AWS service, such as an EC2 Mac instance. Here are instructions to do so.

 *Create* an IAM role that contains the minimum set of permissions to allow `xcodeinstall` to interact with AWS Parameter Store, then *attach* this role to the EC2 Mac instance where you run `xcodeinstall`.

From a machine where the AWS CLI is installed and where you have AWS credentials allowing you to create roles and permissions (typically your laptop), type the following commands :


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

2. Second, create a policy that contains the minimum set of permissions to interact with AWS Parameter Store

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
                "ssm:PutParameter",
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:000000000000:parameter/xcodeinstall/*"
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
aws iam attach-role-policy                                                     \
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
               --filter "Name=tag:Name,Values=M1 Monterey"                               \
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

## How to Store Your Secrets on AWS Parameter Store

When using AWS Parameter Store to store your Apple Developer Portal credentials, you need to create a parameter in the following format:

- **Parameter name:** `/xcodeinstall/apple-credentials`
- **Parameter type:** `SecureString`
- **Parameter value:** JSON with username and password:

```json
{"username":"your_username","password":"your_password"}
```

`xcodeinstall` also maintains a second parameter, `/xcodeinstall/apple-session-token`, which holds the Apple session and cookies. You never create that one yourself — `authenticate` writes it for you.

Both parameters are created with the `Intelligent-Tiering` tier. They stay in the free standard tier while under 4 KB and are promoted automatically to the advanced tier ($0.05/parameter/month) only if the stored session grows past that. Note that this promotion is one-way: an advanced parameter cannot be reverted to standard.

### Using the `storesecrets` Command

The easiest way to create this secret is using the built-in `storesecrets` command:

```bash
➜  ~ xcodeinstall storesecrets -s us-west-2 -p myprofile

This command captures your Apple ID username and password and stores them securely in AWS Parameter Store.
It allows this command to authenticate automatically, as long as no MFA is prompted.

⌨️  Enter your Apple ID username: your.email@example.com
⌨️  Enter your Apple ID password:
✅ Credentials are securely stored
```

**Options:**
- `-s, --secret-region`: AWS region where the parameter will be stored (choose a region close to you for lower latency)
- `-p, --profile`: AWS profile name to use (from `~/.aws/credentials` and `~/.aws/config`)

**Important:** Unlike other commands, `storesecrets` requires you to specify `-s` and `-p` every time, as it's typically a one-time setup operation.

### After Storing Credentials

Once credentials are stored in AWS Parameter Store:

1. Authenticate once with the same region and profile:
   ```bash
   xcodeinstall authenticate -s us-west-2 -p myprofile
   ```

2. The region and profile are saved automatically. Subsequent commands work without flags:
   ```bash
   xcodeinstall list
   xcodeinstall download --name "Xcode 15.2.xip"
   ```

## Troubleshooting

### Configuration Files and Data Locations

`xcodeinstall` stores its files in `~/.xcodeinstall/`:

```bash
~/.xcodeinstall/
├── config.json           # Saved AWS region and profile settings
├── downloadList          # Cached list of available downloads
└── download/             # Downloaded Xcode files
```

### Managing Saved Settings

**View saved settings:**
```bash
cat ~/.xcodeinstall/config.json
```

**Clear saved settings:**
```bash
rm ~/.xcodeinstall/config.json
```

After clearing, you'll need to specify `-s` and `-p` flags again on your next command.

**Reset everything (including downloads and cache):**
```bash
rm -rf ~/.xcodeinstall/
```

### Common Issues

**"Using saved settings" message appears with wrong region/profile:**
- Override with command-line flags: `xcodeinstall list -s us-east-1 -p newprofile`
- Or clear the config file: `rm ~/.xcodeinstall/config.json`

**Session expired errors:**
- Run `xcodeinstall authenticate` (with `-s` and `-p` if using AWS Parameter Store)
- Enter your MFA code when prompted

**AWS credentials not found:**
- Ensure your AWS credentials are configured in `~/.aws/credentials` or via IAM instance profile
- Check that the profile name matches what you specified with `-p`

**Permission denied when installing:**
- Configure passwordless `sudo` (see [Install File](#install-file) section)
- Or run with `sudo` when prompted

## How to Contribute

I welcome all types of contributions, not only code: testing and creating bug reports, documentation, tutorials, etc.
If you are not sure how to get started or how to be useful, contact me at stormacq@amazon.com

I listed a couple of ideas below.

## List of Ideas

**UX Improvements:**
- Download the latest Xcode version by default
- Capture stderr and stdout of subprocess to emit on the logger

**AWS Integration:**
- Add possibility to emit SNS notifications on errors (e.g., Session Expired)
- Support for additional AWS authentication methods (SSO, OIDC)

**Configuration Management:**
- Add explicit config management commands (`config show`, `config clear`)
- Support for multiple named profiles (`--save-as dev`, `--use-profile dev`)
- Environment variable fallback (`XCODEINSTALL_REGION`, `XCODEINSTALL_PROFILE`)

**Completed:**
- [x] Clean room implementation of progress bar to remove dependency on Swift Tools Core library
- [x] Persistent configuration for `-s` and `-p` options
- [x] Manage multiple versions of Xcode (rename `Xcode.app` to `Xcode-version.app` and use symlinks)

## Credits 

[xcode-install](https://github.com/xcpretty/xcode-install) and [fastlane/spaceship](https://github.com/fastlane/fastlane/tree/master/spaceship) both deserve credit for figuring out the hard parts of what makes this possible.
