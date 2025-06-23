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

# update pyproject.toml flow with uv (much more efficient than poetry):
#  - uv can handle batch operations efficiently, unlike poetry which fails on missing packages
#  - uv remove can handle multiple packages and non-existent packages gracefully
#  - uv add can also handle multiple packages in one operation

deps_array=()
packages_to_remove=()

if [ -n "$pinned_deps" ]; then
    pinned_deps_wo_version=$(echo "$pinned_deps" | sed 's/==.*//')
    # Collect packages to remove (uv handles non-existent packages gracefully)
    while IFS= read -r line; do
        packages_to_remove+=("$line")
        deps_array+=("$(echo "$pinned_deps" | grep "^$line==")")
    done <<< "$pinned_deps_wo_version"
fi

if [ -n "$non_pinned_deps" ] && [ "$update_non_pinned_deps" = true ]; then
    while IFS= read -r line; do
        packages_to_remove+=("$line")
        deps_array+=("$line")
    done <<< "$non_pinned_deps"
fi

# uv approach: Use a more direct method to manage the from-lambda-layers group
# Note: TOML uses hyphens in group names, but uv commands use underscores
echo "Managing from-lambda-layers dependency group..."

# First, let's try to remove the entire group if it exists, then recreate it
# This is cleaner than trying to manage individual packages
if grep -q "from-lambda-layers" pyproject.toml; then
    echo "Found existing from-lambda-layers group, clearing it..."
    
    # Get all current packages in the group and remove them
    existing_packages=()
    if grep -q "^\[dependency-groups\.from-lambda-layers\]" pyproject.toml; then
        # PEP 735 format - extract package names
        mapfile -t existing_packages < <(sed -n '/^\[dependency-groups\.from-lambda-layers\]/,/^\[/{//!p;}' pyproject.toml | grep -E '^\s*"[^"]+' | sed -E 's/^\s*"([^"=<>~!]+).*/\1/' | grep -v '^$')
    elif grep -q "^\[tool\.uv\.groups\.from-lambda-layers\]" pyproject.toml; then
        # tool.uv.groups format - extract package names  
        mapfile -t existing_packages < <(sed -n '/^\[tool\.uv\.groups\.from-lambda-layers\]/,/^\[/{//!p;}' pyproject.toml | grep -E '^\s*"[^"]+' | sed -E 's/^\s*"([^"=<>~!]+).*/\1/' | grep -v '^$')
    fi
    
    # Remove all existing packages if any
    if [ "${#existing_packages[@]}" -gt 0 ]; then
        echo "Removing ${#existing_packages[@]} existing packages from from-lambda-layers group"
        # Filter out empty strings
        filtered_packages=()
        for pkg in "${existing_packages[@]}"; do
            if [[ -n "$pkg" ]]; then
                filtered_packages+=("$pkg")
            fi
        done
        
        if [ "${#filtered_packages[@]}" -gt 0 ]; then
            # uv uses underscores in command line but hyphens are in TOML
            uv remove --group from-lambda-layers "${filtered_packages[@]}" || echo "Note: Some packages may not have been in the group"
        fi
    fi
fi

# Now add the new packages we've determined from the lambda layers
if [ "${#deps_array[@]}" -gt 0 ]; then
    echo "Adding ${#deps_array[@]} new packages to from-lambda-layers group"
    # uv uses underscores in command line but hyphens are in TOML
    uv add --group from-lambda-layers "${deps_array[@]}"
else
    echo "No packages to add to from-lambda-layers group"
fi

# uv automatically updates the lock file, no need for separate --lock commands

# clean up
rm -rf "$tmpdir"
