#!/bin/bash

set -e
mike="pipenv run mike"

# using dummy values for user.name and user.email as they are not required for git operations but a requirement for mike
git config user.name "Your Name"
git config user.email "youremail@example.com"

# Fetch all tags
git fetch --tags

# Get all tags
TAGS=$(git tag | head -n 1)

# Calculate the latest and default tags
DEFAULT_TAG=$(echo "$TAGS" | sort -V | head -n 1)

for TAG in $TAGS; do
    echo "Deploying tag: $TAG"
    
    git checkout $TAG

    if [ "$TAG" == "$DEFAULT_TAG" ]; then
        $mike deploy --update-aliases $TAG latest || true
    else
        $mike deploy $TAG || true
    fi
done

$mike list --json > src/versions.json
$mike set-default $DEFAULT_TAG
