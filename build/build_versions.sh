#!/bin/bash

set -e
mike="pipenv run mike"

CURRENT=$(git branch --show-current)
echo "$CURRENT" > .current_branch

# using dummy values for user.name and user.email as they are not required for git operations but a requirement for mike to have gh-pages branch
git config user.name "Wire Docs"
git config user.email "wire-docs-author@wire.com"

# to avoid considering the changes in the following files
echo ".gitignore" >> .gitignore
echo ".current_branch" >> .gitignore
#echo "build" >> .gitignore

# Check if there are any uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
  echo "Uncommitted changes detected. Commiting them temporarily and creating a tag for $CURRENT branch with same name"
  git add -A
  git commit -m "Temporary commit: required to work on other branches"
  # forcing here for tag creaion as the tag might already exist but new commits should be tagged
  git tag -f $CURRENT || true
fi

# tag the current branch only if it is not main
if [ $CURRENT != "main" ] ; then
    git tag $CURRENT || true
fi

# Fetch all tags
git fetch --tags

# Get all tags
TAGS=$(git tag)

# Calculate the latest and default tags
DEFAULT_TAG=$(echo "$TAGS" | sort -V | head -n 1)

# Fetch the existing tags and their commits from mike
declare -A existing_tags
while read -r tag commit; do
    existing_tags[$tag]=$commit
done < <($mike list | awk -F '[][]' '{print $1, $2}')

# Iterate over git tags
git show-ref --tags | while read -r commit tag; do
    TAG=${tag#refs/tags/}

    # Check if tag exists in mike
    if [[ -n "${existing_tags[$TAG]}" ]]; then
        existing_commit="${existing_tags[$TAG]}"

        if [[ "$commit" != "$existing_commit" ]]; then
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

# mark the current branch as default only if it is not main
if [ $CURRENT != "main" ] ; then
    $mike set-default $DEFAULT_TAG
else
    $mike set-default $CURRENT
fi

