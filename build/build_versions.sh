#!/bin/bash

set -ex
printenv
mike="pipenv run mike"
CURRENT=$(git branch --show-current)

# using dummy values for user.name and user.email as they are not required for git operations but a requirement for mike to have gh-pages branch
git config --local user.name "Wire Docs"
git config --local user.email "wire-docs-author@wire.com"
git config --local submodule.recurse false

# this will check if there are warnings in mkdocs build, if any it will exit.
# It will be useful to find if internal referencing is broken
validate_output() {
  local RED='\033[0;31m'
  local output="$1"
  # to get building logs
   echo "$output"
  # ignoring changelog.md as it is talking about past changes
  remaining_warnings=$(echo "$output" | grep -i "WARNING" | grep -v "Doc file 'changelog/changelog.md' contains a link" | awk '{$1=$1};1')

  if [ -n "$remaining_warnings" ]; then
    echo -e "${RED}Errors found in the output:"
    echo "$remaining_warnings"
    exit 1
  fi
}

# checking if it is building from a branch
if [ -n "$CURRENT" ]; then
  # if building locally, the local tag would be CURRENT_TAG
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
    elif [[ "${GITHUB_REF}" == refs/pull/* ]]; then
      # we build latest everytime there is PR
      CURRENT_TAG="latest"
    fi
  fi
fi

# Rule: Build latest when push is successful to main branch
if [[ "${CURRENT_TAG}" == "main" ]]; then
  CURRENT_TAG="latest"
fi

git tag -f $CURRENT_TAG || true

# Fetch the existing tags and their commits from mike
declare -A existing_tags
while read -r tag commit; do
    existing_tags[$tag]=$commit
done < <($mike list | awk -F '[][]' '{print $1, $2}')

commit=$(git show-ref "refs/tags/${CURRENT_TAG}" | awk '{print $1}')
git checkout ${CURRENT_TAG}
    
# pull the submodule
git submodule update --init --depth 1 wire-server
    
# Check if tag exists in mike
if [ -n "${existing_tags[$CURRENT_TAG]}" ]; then
    existing_commit="${existing_tags[$CURRENT_TAG]}"
    if [ "$commit" != "$existing_commit" ]; then
        echo "Tag $CURRENT_TAG exists but with a different commit ($existing_commit). Updating..."
        $mike delete "$CURRENT_TAG"
        output=$($mike deploy --update-aliases "$CURRENT_TAG" "$commit" 2>&1)
        validate_output "$output"
    else
        echo "Tag $CURRENT_TAG already exists with the same commit ($commit). Skipping deployment."
    fi
else
    echo "Tag $CURRENT_TAG does not exist. Deploying..."
    output=$($mike deploy --update-aliases "$CURRENT_TAG" "$commit" 2>&1)
    validate_output "$output"
  fi

# deinit the submodule to avoid issues with the next iteration
git submodule deinit -f wire-server

# Set the default tag and create an alias to $CURRENT_TAG
$mike set-default $CURRENT_TAG
