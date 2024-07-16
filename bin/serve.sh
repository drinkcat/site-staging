#!/bin/bash

basedir=$(realpath $(dirname "$0")/..)

PORT=4000

cd $basedir
# JEKYLL_ENV=production could be added
bundle exec jekyll serve --livereload --port $PORT
