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

# Check if YAML file exists
if [ ! -f "$yaml_file" ]; then
  echo "Error: YAML file '$yaml_file' not found."
  exit 1
fi

# Function to check if folder exists in the repo at the specified branch and path
function folder_exists_in_repo {
    local repoURL="$1"
    local branch="$2"
    local path="$3"

    # Clone the repository to a temporary directory
    temp_dir=$(mktemp -d)
    echo using tempdir $temp_dir
    if [ "$branch" == "HEAD" ]; then
        git clone "$repoURL" "$temp_dir" >/dev/null 2>&1
    else
        git clone --branch "$branch" "$repoURL" "$temp_dir" >/dev/null 2>&1
    fi

    # Navigate to the directory
    cd "$temp_dir" || return 1

    # Check if the path exists in the repo
    if ls "$path" >/dev/null; then
        echo "Folder '$path' exists in branch '$branch' of the repository."
##COMMENT BELOW LINE TO DEBUG
        rm -rf "$temp_dir"
        return 0
    else
        echo "Folder '$path' does not exist in branch '$branch' of the repository."
##COMMENT BELOW LINE TO DEBUG
        rm -rf "$temp_dir"
        return 1
    fi
}

# Read YAML file and extract repoURL, branch, and path
repoURL=$(yq e '.spec.source.repoURL' "$yaml_file")
targetRevision=$(yq e '.spec.source.targetRevision' "$yaml_file")
path=$(yq e '.spec.source.path' "$yaml_file")

echo "Testing $repoURL $targetRevision $path"

# Determine the branch to use (handling "HEAD" case)
if [ "$targetRevision" == "HEAD" ]; then
    branch="master"  # Default to master branch (or specify another default branch)
else
    branch="$targetRevision"
fi

# Usage example
if folder_exists_in_repo "$repoURL" "$branch" "$path"; then
    echo "Folder exists!"
        echo you can create this application now, by git add/commit/push
else
    echo "Folder does not exist."
    echo do not create this application yet
fi
