#!/bin/bash

# Check prerequisites
if ! hash lambda-local 2>/dev/null; then
  echo lambda-local is not installed
  echo You can install it by running: npm install lambda-local -g
  exit
fi

if [ ! -f ".env" ]; then
    echo "You need to make a copy of .env.sample and rename it to .env, and then fill in the variables"
    exit
fi

# https://www.npmjs.com/package/lambda-local
lambda-local -l index.js -e event.js -t 60 --envfile .env
