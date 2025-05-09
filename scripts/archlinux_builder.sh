#!/bin/bash
# Fail on error
set -euo pipefail
# Change to the repository root directory
cd "$(dirname "$0")"/..

# Initialize Packer (downloads plugins, etc.)
packer init packer/

# Run the Packer build and capture the exit code
packer build -force -on-error=ask packer/
PACKER_EXIT_CODE=$?

if [ "$PACKER_EXIT_CODE" -eq 0 ]; then
  # Get the current Git commit hash
  COMMIT_HASH=$(git rev-parse HEAD)

  # Find the most recently modified directory in outputs/
  LATEST_OUTPUT=$(find packer/outputs/ -mindepth 1 -maxdepth 1 -type d -printf "%T@ %p\n" | sort -nr | head -n 1 | cut -d' ' -f2-)

  if [ -n "$LATEST_OUTPUT" ]; then
    # Create a version.txt file in the created output directory
    echo "$COMMIT_HASH" > "$LATEST_OUTPUT/version.txt"
    echo "Written commit $COMMIT_HASH to $LATEST_OUTPUT/version.txt"
  else
    echo "No output directory found."
    exit 1
  fi
fi
