#!/bin/bash

set -ex
mike="pipenv run mike"

CURRENT=$(git branch --show-current)

# using dummy values for user.name and user.email as they are not required for git operations but a requirement for mike to have gh-pages branch
git config --local user.name "Wire Docs"
git config --local user.email "wire-docs-author@wire.com"

# it will work only when building from branches which is expected to run in local setup
if [ -n "$CURRENT" ]; then
  CURRENT_TAG="$CURRENT"

  if [ -f ".current_branch" ]; then
    PREVIOUS=$(<.current_branch)
    # to let local user know that the branch has been while developing locally
    # this will lead to a new tag creation for the branch, it will not be used when running in github actions
    if [ "$CURRENT" != "$PREVIOUS" ]; then
      echo "Branch changed from '$PREVIOUS' to '$CURRENT'"
      echo "$CURRENT" > .current_branch
    fi
  else
    echo "$CURRENT" > .current_branch
  fi

  # useful for local users to see their diffs with each mike deploy
  git --no-pager diff

  # Check if there are any uncommitted changes, expected when building locally
  if [[ -n $(git status --porcelain) ]]; then
    echo "TAG used for current commit would be: $CURRENT_TAG"
    echo "Uncommitted changes detected. Commiting them temporarily and creating a tag for $CURRENT_TAG Tag/branch with same name"
    git add -A
    git commit -m "Temporary commit: required to work on other branches"
  fi

  # forcing here for tag creaion as the tag might already exist but new commits should be tagged
  git tag -f $CURRENT_TAG || true
  git tag -f latest || true

# Confirming if we are in GitHub Actions environment
else
  if [ -n "${GITHUB_REF}" ]; then
    if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
      # For a tag, strip the "refs/tags/" prefix.
      CURRENT_TAG="${GITHUB_REF#refs/tags/}"
    elif [[ "${GITHUB_REF}" == refs/pull/* ]]; then
      # For a pull request, remove "refs/pull/" then replace "/" with "-" to get "11-merge"
      pr_part="${GITHUB_REF#refs/pull/}"s
      CURRENT_TAG="${pr_part//\//-}"
      git tag -f $CURRENT_TAG || true
      git tag -f latest || true
    fi
  fi
fi

# Get all tags
TAGS=$(git tag)

# Fetch the existing tags and their commits from mike
declare -A existing_tags
while read -r tag commit; do
    existing_tags[$tag]=$commit
done < <($mike list | awk -F '[][]' '{print $1, $2}')

# Iterate over git tags
git show-ref --tags | while read -r commit tag; do
    TAG=${tag#refs/tags/}
    git checkout $TAG
    
    # pull the submodule
    git submodule update --init
    
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

# Set the default tag and create an alias to latest
$mike set-default latest
