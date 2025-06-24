#!/usr/bin/env bash

set -e

update_non_pinned_deps=$1
layers=$2
package_manager=$3

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

if [ "$package_manager" = "poetry" ]; then
    # Poetry workflow (original logic)
    echo "Using Poetry workflow..."
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

elif [ "$package_manager" = "uv" ]; then
    # UV workflow (more efficient batch operations)
    echo "Using UV workflow..."
    deps_array=()

    if [ -n "$pinned_deps" ]; then
        pinned_deps_wo_version=$(echo "$pinned_deps" | sed 's/==.*//')
        while IFS= read -r line; do
            deps_array+=("$(echo "$pinned_deps" | grep "^$line==")")
        done <<< "$pinned_deps_wo_version"
    fi

    if [ -n "$non_pinned_deps" ] && [ "$update_non_pinned_deps" = true ]; then
        while IFS= read -r line; do
            deps_array+=("$line")
        done <<< "$non_pinned_deps"
    fi

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
else
    echo "Error: Unknown package manager '$package_manager'. Expected 'poetry' or 'uv'."
    exit 1
fi

# clean up
rm -rf "$tmpdir"
