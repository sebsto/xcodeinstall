# Setting Up the Homebrew Formula Update GitHub Action

This document provides instructions for setting up and using the new GitHub Action that automatically updates the Homebrew formula when a new release is published.

## Overview

The GitHub Action workflow in `.github/workflows/update-homebrew.yml` uses the `dawidd6/action-homebrew-bump-formula` action to automatically update the Homebrew formula in the `sebsto/homebrew-macos` tap repository when a new release is published.

## Setup Instructions

### 1. Create a GitHub Personal Access Token (PAT)

The workflow requires a GitHub Personal Access Token with permissions to push to the `sebsto/homebrew-macos` repository.

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

### 2. Add the Token as a Repository Secret

1. Go to the xcodeinstall repository settings
2. Navigate to Secrets and variables > Actions
3. Click "New repository secret"
4. Name: `HOMEBREW_TAP_TOKEN`
5. Value: Paste the personal access token you created
6. Click "Add secret"

## Using the Workflow

Once the setup is complete, the workflow will automatically run whenever a new release is published on GitHub.

### Creating a New Release

1. Update the VERSION file with the new version number
2. Update the CHANGELOG with the changes in the new version
3. Commit and push these changes
4. Create a new release on GitHub:
   - Go to the repository on GitHub
   - Click on "Releases" in the right sidebar
   - Click "Create a new release"
   - Enter the tag version (e.g., `v0.10.2`)
   - Enter a title for the release
   - Add release notes (you can use the "Generate release notes" button)
   - Click "Publish release"

5. The workflow will automatically run and update the Homebrew formula in the `sebsto/homebrew-macos` tap repository

### Monitoring the Workflow

You can monitor the workflow execution in the "Actions" tab of the repository on GitHub. If the workflow fails, you can check the logs to see what went wrong.

## Troubleshooting

### Common Issues

1. **Workflow fails with "Permission denied" error**:
   - Check that the `HOMEBREW_TAP_TOKEN` secret is correctly set
   - Verify that the token has the necessary permissions for the `sebsto/homebrew-macos` repository

2. **Workflow fails with "Formula not found" error**:
   - Check that the formula name in the workflow file matches the formula name in the tap repository

3. **Workflow fails with "No changes detected" error**:
   - This can happen if the formula is already up-to-date
   - You can set the `force` parameter to `true` in the workflow file to force an update

### Manual Fallback

If the workflow fails, you can still update the formula manually using the existing scripts:

```bash
./scripts/deploy/release_sources.sh
./scripts/deploy/release_binaries.sh
```

## Conclusion

This GitHub Action workflow automates the process of updating the Homebrew formula when a new release is published, making it more efficient and less error-prone. If you have any questions or issues, please refer to the documentation in `.github/workflows/README.md` or open an issue on GitHub.