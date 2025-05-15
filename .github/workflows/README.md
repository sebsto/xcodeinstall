# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the xcodeinstall project.

## Workflows

### Build and Test on EC2 (`build_and_test.yml`)
Builds and tests the project on a self-hosted runner.

### Build and Test on GitHub (`build_and_test_gh_hosted.yml`)
Builds and tests the project on GitHub-hosted runners.

### Update Homebrew Formula (`update-homebrew.yml`)
Automatically updates the Homebrew formula in the `sebsto/homebrew-macos` tap when a new release is published.

## Setting up the Homebrew Formula Update Workflow

The `update-homebrew.yml` workflow requires a GitHub Personal Access Token (PAT) with permissions to push to the `sebsto/homebrew-macos` repository.

### Creating a Personal Access Token

1. Go to your GitHub account settings
2. Navigate to Developer settings > Personal access tokens > Fine-grained tokens
3. Click "Generate new token"
4. Give the token a descriptive name like "Homebrew Formula Update"
5. Set the expiration as needed
6. Select the `sebsto/homebrew-macos` repository under "Repository access"
7. Grant the following permissions:
   - Contents: Read and write
   - Metadata: Read-only
8. Click "Generate token"
9. Copy the generated token

### Adding the Token as a Repository Secret

1. Go to the xcodeinstall repository settings
2. Navigate to Secrets and variables > Actions
3. Click "New repository secret"
4. Name: `HOMEBREW_TAP_TOKEN`
5. Value: Paste the personal access token you created
6. Click "Add secret"

Once this is set up, the workflow will automatically update the Homebrew formula whenever a new release is published.