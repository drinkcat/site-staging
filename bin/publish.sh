#!/bin/bash

set -e

field="date"
if [[ $1 == "-u" ]]; then
    field="last_modified_at"
    shift
fi

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
    exit 1
fi

if [[ "$field" == "date" ]]; then
    newfile="$dir"/"$newbase"
    if [[ "$base" != "$newbase" ]]; then
        git mv "$file" "$newfile"
    fi
else
    newfile="$file"
fi

newdate=$(date --rfc-3339=seconds)

sed -i -e "s/^$field: .*/$field: $newdate/" "$newfile"
git add "$newfile"
git commit -m "$newfile: publish" -e

echo "Check the commit, then git push."

