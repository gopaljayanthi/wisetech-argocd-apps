#!/bin/bash

repoURL="https://github.com/gopaljayanthi/wisetech-k8s-repo"
branch="main"  # Specify the branch you want to check
path="testonce-mainchart/uat"  # Specify the path to check within the repository

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

# Usage example
if folder_exists_in_repo "$repoURL" "$branch" "$path"; then
    echo "Folder exists!"
else
    echo "Folder does not exist."
fi
