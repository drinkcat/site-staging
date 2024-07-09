#!/bin/bash

branch="$1"

git merge --squash "$branch"

echo "Merge $branch" > .git/SQUASH_MSG
git diff --staged | diffstat | sed -e 's/^/# /' >> .git/SQUASH_MSG
git commit -F .git/SQUASH_MSG -e

