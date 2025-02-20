#!/bin/bash
set -xeuo pipefail

# Get the current directory (i.e. the original working directory)
ORIGINAL_DIR=$(pwd)

if [ -f .tmpdir ]; then 
	if [ ! -d "$(cat .tmpdir)" ]; then 
		mktemp -d > .tmpdir
	fi
else 
	mktemp -d > .tmpdir 
fi

TEMP_DIR=$(cat .tmpdir)
echo "Using temporary directory: $TEMP_DIR"

# only used when working locally
if [ -f $TEMP_DIR/.current_branch ]; then 
	cd $TEMP_DIR;
    # reverting to the branch that was being worked on
	git checkout $(cat $TEMP_DIR/.current_branch); 
	echo "Working on branch $(cat $TEMP_DIR/.current_branch)"; 
else 
	echo "no .current_branch file found"; 
fi; 

if [ -d "$TEMP_DIR/.git" ]; then
    current_remote=$(git config --get remote.origin.url)
    if [ "$current_remote" = "$ORIGINAL_DIR" ]; then
      cd $TEMP_DIR

      EXPECTED_AUTHOR="Wire Docs <wire-docs-author@wire.com>"
      LAST_COMMIT_AUTHOR=$(git log -1 --pretty=format:"%an <%ae>")
      if [ "$LAST_COMMIT_AUTHOR" = "$EXPECTED_AUTHOR" ]; then
          echo "Last commit by $EXPECTED_AUTHOR detected. Removing it..."
          git reset --hard HEAD~1
          git pull origin $(cat .current_branch)
      else
          echo "Last commit was not by $EXPECTED_AUTHOR. No action taken."
      fi

    else
        echo "${TEMP_DIR} exists and the remote ${ORIGINAL_DIR} has changed from previous source. Clean and try again."
        exit 1
    fi
else
    echo "Cloning repository to ${TEMP_DIR}"
    git clone "${ORIGINAL_DIR}" "${TEMP_DIR}"
fi

echo "Syncing all the other files changes from ${ORIGINAL_DIR}/ to ${TEMP_DIR}, to have uncommited changes, if any"
rsync -a --exclude='/.git' --exclude="/wire-server" --exclude='wire-docs*.tar.gz' --exclude=".tmpdir" "${ORIGINAL_DIR}/" "$TEMP_DIR/"
