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

echo "Copying files from $ORIGINAL_DIR to $TEMP_DIR"

# to remove undesired files from the temporary directory
remove_if_exists() {
  local pattern="$1"
  local files=()
  local exit_code=0

  # Enable nullglob so non-matching patterns expand to an empty array
  shopt -s nullglob
  files=( $pattern )
  shopt -u nullglob

  if [ ${#files[@]} -eq 0 ]; then
    return 0
  fi

  for file in "${files[@]}"; do
    if [ -e "$file" ]; then
        rm -f "$file"
    fi
  done
}

cp -a "${ORIGINAL_DIR}/." $TEMP_DIR

# removing the files not required in the temporary directory but got copied; rsync works better but rsync availability before nix can't be assured
remove_if_exists $TEMP_DIR/.tmpdir
remove_if_exists $TEMP_DIR/wire-docs*.tar.gz
