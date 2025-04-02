#!/bin/bash

set -ex
mike="pipenv run mike"

CURRENT=$(git branch --show-current)

# using dummy values for user.name and user.email as they are not required for git operations but a requirement for mike to have gh-pages branch
git config --local user.name "Wire Docs"
git config --local user.email "wire-docs-author@wire.com"
git config --local submodule.recurse false

# checking if it is building from a branch
if [ -n "$CURRENT" ]; then
  CURRENT_TAG="$CURRENT"

  # useful for local users to see their diffs with each mike deploy
  git --no-pager diff

  # Check if there are any uncommitted changes, expected when building locally
  if [[ -n $(git status --porcelain) ]]; then
    echo "TAG used for current commit would be: $CURRENT_TAG"
    echo "Uncommitted changes detected. Commiting them temporarily and creating a tag for $CURRENT_TAG Tag/branch with same name"
    git add -A
    git commit -m "Temporary commit: required to work on other branches"
  fi

# Confirming if we are in GitHub Actions environment
else
  if [ -n "${GITHUB_REF}" ]; then
    if [[ "${GITHUB_REF}" == refs/tags/* ]]; then
      # For a tag, strip the "refs/tags/" prefix.
      CURRENT_TAG="${GITHUB_REF#refs/tags/}"
      # creating a tag when releasing a tag
      git tag -f $CURRENT_TAG || true
    elif [[ "${GITHUB_REF}" == refs/pull/* ]]; then
      # For a pull request, remove "refs/pull/" then replace "/" with "-" to get "11-merge"
      pr_part="${GITHUB_REF#refs/pull/}"s
      CURRENT_TAG="${pr_part//\//-}"
    fi
  fi

fi

# always build the latest tag
git tag -f latest || true

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
    git submodule update --init wire-server
    
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

    # deinit the submodule to avoid issues with the next iteration
    git submodule deinit -f wire-server
done

# Set the default tag and create an alias to latest
$mike set-default latest
