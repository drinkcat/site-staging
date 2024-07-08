#!/bin/bash

basedir=$(realpath $(dirname "$0")/..)

PORT=4000

cd $basedir
bundle exec jekyll serve --livereload --port $PORT
