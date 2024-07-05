#!/bin/bash

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: yq (YAML processor) is required but not installed."
    echo "Please install yq before running this script."
    exit 1
fi

# Check if argument is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <yaml_file>"
  exit 1
fi

yaml_file="$1"

# Function to check if folder exists in the repo at the specified branch and path
function folder_exists_in_repo {
    local repoURL="$1"
    local branch="$2"
    local path="$3"

    # Clone the repository to a temporary directory
    temp_dir=$(mktemp -d)
    git clone --depth 1 --branch "$branch" "$repoURL" "$temp_dir" >/dev/null 2>&1

    # Navigate to the directory
    cd "$temp_dir" || return 1

    # Check if the path exists in the repo
    if git ls-tree -r "$branch" -- "$path" >/dev/null 2>&1; then
        echo "Folder '$path' exists in branch '$branch' of the repository."
        rm -rf "$temp_dir"
        return 0
    else
        echo "Folder '$path' does not exist in branch '$branch' of the repository."
        rm -rf "$temp_dir"
        return 1
    fi
}

# Read YAML file and extract repoURL, branch, and path
repoURL=$(yq e '.spec.source.repoURL' "$yaml_file")
#branch=$(yq e '.spec.source.targetRevision' "$yaml_file")
branch=master
path=$(yq e '.spec.source.path' "$yaml_file")

# Usage example
if folder_exists_in_repo "$repoURL" "$branch" "$path"; then
    echo "Folder exists!"
else
    echo "Folder does not exist."
fi
