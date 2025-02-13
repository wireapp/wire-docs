#!/bin/bash

set -ex
mike="pipenv run mike"

CURRENT=$(git branch --show-current)

if [ -f ".current_branch" ]; then
  PREVIOUS=$(<.current_branch)
  # to let local user know that the branch has been while developing locally
  # this will lead to a new tag creation for the branch
  if [ "$CURRENT" != "$PREVIOUS" ]; then
    echo "Branch changed from '$PREVIOUS' to '$CURRENT'"
    echo "$CURRENT" > .current_branch
  fi
else
  echo "$CURRENT" > .current_branch
fi

# using dummy values for user.name and user.email as they are not required for git operations but a requirement for mike to have gh-pages branch
git config --local user.name "Wire Docs"
git config --local user.email "wire-docs-author@wire.com"

# Checking if we are in github actions environment or working locally
if [ -n "${GITHUB_REF_NAME}" ]; then
  CURRENT_TAG="$GITHUB_REF_NAME"
elif [ -n "${GITHUB_REF}" ]; then
  CURRENT_TAG="${GITHUB_REF##*/}"
else
  CURRENT_TAG="$CURRENT"
fi

echo "TAG used for current commit would be: $CURRENT_TAG"

# to avoid considering the changes in the following files
echo ".current_branch" >> .gitignore

# useful for local users to see their diffs with each mike deploy
git --no-pager diff

# Check if there are any uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "Uncommitted changes detected. Commiting them temporarily and creating a tag for $CURRENT_TAG Tag/branch with same name"
  git add -A
  git commit -m "Temporary commit: required to work on other branches"
  # forcing here for tag creaion as the tag might already exist but new commits should be tagged
  git tag -f $CURRENT_TAG || true
fi

# Fetch all tags
git fetch --tags

# Get all tags
TAGS=$(git tag)

# Calculate the latest and default tags
DEFAULT_TAG=$(echo "$TAGS" | sort -V | tail -n 1)

# Fetch the existing tags and their commits from mike
declare -A existing_tags
while read -r tag commit; do
    existing_tags[$tag]=$commit
done < <($mike list | awk -F '[][]' '{print $1, $2}')

# Iterate over git tags
git show-ref --tags | while read -r commit tag; do
    TAG=${tag#refs/tags/}

    # Check if tag exists in mike
    if [ -n "${existing_tags[$TAG]}" ]; then
        existing_commit="${existing_tags[$TAG]}"

        if [ "$commit" != "$existing_commit" ]; then
            echo "Tag $TAG exists but with a different commit ($existing_commit). Updating..."
            $mike delete "$TAG"
            $mike deploy --update-aliases "$TAG" "$commit"
        else
            echo "Tag $TAG already exists with the same commit ($commit). Skipping deployment."
        fi
    else
        echo "Tag $TAG does not exist. Deploying..."
        $mike deploy --update-aliases "$TAG" "$commit"
    fi
done

# Set the default tag
$mike set-default $CURRENT_TAG
