#!/usr/bin/env bash

set -e

cd /workspace

echo "Upgrading npm"
# The npm inside CodeBuild standard image is too old, we need to apply the workaround https://github.com/npm/cli/issues/1756
# to get rid of the ENOLOCAL error: Could not install from "../../../../../../../../ansible" as it does not contain a package.json file.
npm --no-progress --no-color --audit=false install -g npm
echo "Installing npm dependencies"
npm --no-progress --no-color --audit=false ci --ignore-scripts --no-fund
echo "Building the application"
npm --no-progress --no-color --audit=false run build --if-present
echo "Pruning the extraneous packages"
NODE_ENV=production npm --no-progress --no-color --audit=false prune --production --no-fund
echo "Moving node_modules to the output folder"
mv ./node_modules /output/
echo "Packing release files"
# there is no jq and tar inside the Lambda runtime container, we do the post-processing outside
npm --no-progress --no-color --audit=false pack --ignore-scripts --json > npm-pack-output.json
echo "all done!"
