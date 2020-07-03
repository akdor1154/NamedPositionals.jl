#!/bin/bash

set -ex

repoPath="${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}"
hash="${CIRCLE_SHA1}"
token="${GITHUB_COMMENTER_TOKEN}"

curl -fL \
    -u :"${token}" \
    -d '{"body": "[CircleCI-triggered]\nJuliaRegistrator register"}' \
    -X POST \
    "https://api.github.com/repos/${repoPath}/commits/${hash}/comments"
