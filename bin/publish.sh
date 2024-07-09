#!/bin/bash

set -e

file="$1"

if [[ ! -f "$file" ]]; then
    echo "'$file' to be published doesn't exist."
    exit 1
fi

set -x

dir="$(dirname $file)"
base="$(basename $file)"
basenodate="$(echo "$base" | sed -n s/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-//p)"
newbase="$(date +%Y-%m-%d-)${basenodate}"

if [[ -z "$basenodate" ]]; then
    echo "ERROR: $file doesn't already start with a date."
    git checkout $branch
    exit 1
fi

git checkout $branch -- $file
newfile="$dir"/"$newbase"
if [[ "$base" != "$newbase" ]]; then
    git mv "$file" "$newfile"
fi

newdate=$(date --rfc-3339=seconds)

sed -i -e "s/^date: .*/date: $newdate/" "$newfile"
git add "$newfile"
git commit -m "$newfile: publish" -e

echo "Check the commit, then git push."

