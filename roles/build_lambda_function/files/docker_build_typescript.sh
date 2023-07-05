#!/usr/bin/env bash

set -e

cd /workspace

echo "Upgrading npm"
# The npm inside CodeBuild standard image is too old, we need to apply the workaround https://github.com/npm/cli/issues/1756
# to get rid of the ENOLOCAL error: Could not install from "../../../../../../../../ansible" as it does not contain a package.json file.
npm --no-progress --no-color --no-audit --no-fund install -g npm
echo "Installing npm dependencies"
npm --no-progress --no-color --no-audit --no-fund ci --ignore-scripts
echo "Building the application"
npm --no-progress --no-color --no-audit --no-fund run build --if-present
echo "Packing release files"
# there is no jq and tar inside the Lambda runtime container, we do the post-processing outside
npm --no-progress --no-color --no-audit --no-fund pack --ignore-scripts --json > npm-pack-output.json
echo "Pruning the extraneous packages"
NODE_ENV=production npm --no-progress --no-color --no-audit --no-fund prune --omit=dev
echo "Moving node_modules to the output folder"
# BUGFIX-20230704: we cannot use `mv` here, because for mounted volumes, Rancher Desktop has a different symlink file
# permission handling logic compared to Docker Desktop (due to the different underlying VMs).
cp --recursive --no-preserve=ownership ./node_modules /output/
rm -rf ./node_modules
echo "all done!"
