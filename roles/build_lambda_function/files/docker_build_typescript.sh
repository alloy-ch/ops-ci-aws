#!/usr/bin/env bash

cd /workspace

echo "installing npm dependencies"
npm --no-progress --no-color ci --ignore-scripts --audit=false
echo "building the application"
npm --no-progress --no-color run build --if-present
if [ $? -ne 0 ]; then
  npx tsc
fi
echo "pruning the extraneous packages"
# the npm 6 inside the AWS lambda runtime docker has problem with `npm --no-progress --no-color prune --production`, we apply a workaround here
rm -rf node_modules && NODE_ENV=production npm --no-progress --no-color ci --ignore-scripts --only=production --no-optional --omit=dev --audit=false
npm --no-progress --no-color prune --production
echo "all done!"
