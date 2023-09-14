#!/usr/bin/env bash

set -e

update_non_pinned_deps=$1
layers=$2

# create a temporary directory
tmpdir=$(mktemp -d)
pushd "$tmpdir"

# gather lambda layers dependencies
for layer in ${layers//,/ }
do
    URL=$(aws lambda get-layer-version-by-arn --arn "$layer" --query Content.Location --output text)
    curl "$URL" -o layer.zip > /dev/null
    unzip -o layer.zip > /dev/null
    rm layer.zip
done
all_deps=$(pip list --format=freeze --path python --path python/lib/python3.10/site-packages --exclude wheel --exclude  pip --exclude distribute)
pinned_deps=$(echo "$all_deps" | grep "==")
non_pinned_deps=$(echo "$all_deps" | grep -v "==" | sed 's/@.*//')
popd

# update pyproject.toml flow:
#  - remove all dependencies from poetry that are pinned in the lambda layers (NOTE: they must exist be in both the lambda layers and pyproject.toml)
#  - (optional if update_non_pinned_deps==true) remove all dependencies from poetry that are not pinned but existing in the lambda layers (NOTE: they must exist be in both the lambda layers and pyproject.toml)
#  - add all dependencies (with the lambda layers pinning) to poetry
# get all dependencies from pyproject.toml
deps_array=()
if [ -n "$pinned_deps" ]; then
  pinned_deps_wo_version=$(echo "$pinned_deps" | sed 's/==.*//')
  # NOTE: we don't remove them all at once because it will fail if one of them is not in poetry
  while IFS= read -r line; do
    poetry remove --lock "$line" || true
  done <<< "$pinned_deps_wo_version"
  while IFS= read -r line; do
    deps_array+=("$line")
  done <<< "$pinned_deps"
fi

if [ -n "$non_pinned_deps" ] && [ "$update_non_pinned_deps" = true ]; then
  while IFS= read -r line; do
    poetry remove --lock "$line" || true
    deps_array+=("$line")
  done <<< "$non_pinned_deps"
fi
if [ "${#deps_array[@]}" -gt 0 ]; then
  poetry add --lock --group from_lambda_layers "${deps_array[@]}"
fi
# clean up
rm -rf "$tmpdir"
