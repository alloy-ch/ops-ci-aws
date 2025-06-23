#!/usr/bin/env bash

set -e
cd /var/runtime

strict=false
only=""
with=""
without=""
# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: ./script.sh [OPTIONS]"
            echo "Options:"
            echo "  -h, --help"
            echo "  -s, --strict"
            echo "  -o, --only <group1> <group2> ..."
            echo "  -w, --with <group1> <group2> ..."
            echo "  -wo, --without <group1> <group2> ..."
            exit 0
            ;;
        -s|--strict)
            strict=true
            shift
            ;;
        -o|--only)
            # get all values next to the option
            shift
            while [[ $# -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
                if [ -z "$only" ]; then
                    only="$1"
                else
                    only="$only,$1"
                fi
                shift
            done
            ;;
        -w|--with)
            # get all values next to the option
            shift
            while [[ $# -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
                if [ -z "$with" ]; then
                    with="$1"
                else
                    with="$with,$1"
                fi
                shift
            done
            ;;
        -wo|--without)
            # get all values next to the option
            shift
            while [[ $# -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
                if [ -z "$without" ]; then
                    without="$1"
                else
                    without="$without,$1"
                fi
                shift
            done
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# check that boto3 and botocore in pyproject.toml is the same as in the lambda runtime
runtime_boto3_version=$(python -c "import boto3;print(boto3.__version__)")
runtime_botocore_version=$(python -c "import botocore;print(botocore.__version__)")

# Support both dependency-groups and tool.uv.groups formats
pyproject_boto3_version=""
pyproject_botocore_version=""

pyproject_boto3_version=$(cat /workspace/pyproject.toml | grep '"boto3==' | cut -d'=' -f3 | cut -d'"' -f1)
pyproject_botocore_version=$(cat /workspace/pyproject.toml | grep '"botocore==' | cut -d'=' -f3 | cut -d'"' -f1)

if [ "$runtime_boto3_version" != "$pyproject_boto3_version" ] || [ "$runtime_botocore_version" != "$pyproject_botocore_version" ]; then
    echo "boto3 and botocore versions in pyproject.toml and lambda runtime are not the same"
    # echo the whole pyproject.toml file
    file_content=$(cat /workspace/pyproject.toml)
    echo "runtime: boto3==$runtime_boto3_version, botocore==$runtime_botocore_version"
    echo "pyproject.toml: boto3==$pyproject_boto3_version, botocore==$pyproject_botocore_version."
    if [ "$strict" = true ]; then
        echo "Strict mode is enabled. Exiting."
        exit 1
    fi
fi

cd /workspace
echo "Install uv"
pip --quiet --disable-pip-version-check --no-color install --no-cache-dir uv tomli

echo "Installing dependencies with uv"
# construct the command - uv sync is much faster than individual installs
cmd="uv sync --no-dev"

# Use uv's native group options
if [ -n "$only" ]; then
    # Use --only-group for each group (replace commas with spaces and iterate)
    for group in $(echo "$only" | tr ',' ' '); do
        cmd="$cmd --only-group $group"
    done
else
    # Handle --with and --without using native uv options
    if [ -n "$with" ]; then
        for group in $(echo "$with" | tr ',' ' '); do
            cmd="$cmd --group $group"
        done
    fi
    
    if [ -n "$without" ]; then
        for group in $(echo "$without" | tr ',' ' '); do
            cmd="$cmd --no-group $group"
        done
    fi
fi

echo "Running: $cmd"
eval "$cmd"

# Get packages to remove - support both dependency-groups and tool.uv.groups formats
lambda_packages=()
runtime_packages=()

# Extract packages from dependency-groups format
if grep -q "^\[dependency-groups\.from-lambda-layers\]" pyproject.toml; then
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract package name from quoted dependency string like "boto3==1.38.36"
            package_name=$(echo "$line" | sed -E 's/^\s*"([^=<>~!]+).*/\1/')
            if [[ -n "$package_name" ]]; then
                lambda_packages+=("$package_name")
            fi
        fi
    done < <(sed -n '/^\[dependency-groups\.from-lambda-layers\]/,/^\[/{//!p;}' pyproject.toml | grep -E '^\s*"[^"]+' | grep -v '^$')
fi

if grep -q "^\[dependency-groups\.runtime\]" pyproject.toml; then
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract package name from quoted dependency string like "boto3==1.38.36"
            package_name=$(echo "$line" | sed -E 's/^\s*"([^=<>~!]+).*/\1/')
            if [[ -n "$package_name" ]]; then
                runtime_packages+=("$package_name")
            fi
        fi
    done < <(sed -n '/^\[dependency-groups\.runtime\]/,/^\[/{//!p;}' pyproject.toml | grep -E '^\s*"[^"]+' | grep -v '^$')
fi

# Extract packages from tool.uv.groups format
if grep -q "^\[tool\.uv\.groups\.from-lambda-layers\]" pyproject.toml; then
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract package name from quoted dependency string like "boto3==1.38.36"
            package_name=$(echo "$line" | sed -E 's/^\s*"([^=<>~!]+).*/\1/')
            if [[ -n "$package_name" ]]; then
                lambda_packages+=("$package_name")
            fi
        fi
    done < <(sed -n '/^\[tool\.uv\.groups\.from-lambda-layers\]/,/^\[/{//!p;}' pyproject.toml | grep -E '^\s*"[^"]+' | grep -v '^$')
fi

if grep -q "^\[tool\.uv\.groups\.runtime\]" pyproject.toml; then
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract package name from quoted dependency string like "boto3==1.38.36"
            package_name=$(echo "$line" | sed -E 's/^\s*"([^=<>~!]+).*/\1/')
            if [[ -n "$package_name" ]]; then
                runtime_packages+=("$package_name")
            fi
        fi
    done < <(sed -n '/^\[tool\.uv\.groups\.runtime\]/,/^\[/{//!p;}' pyproject.toml | grep -E '^\s*"[^"]+' | grep -v '^$')
fi

removable_packages=("${lambda_packages[@]}" "${runtime_packages[@]}")

echo "Removing pinned dependencies from site-packages"
for package in "${removable_packages[@]}"
do
    # Remove package directories
    rm -rf .venv/lib/python*/site-packages/"$package"
    rm -rf .venv/lib/python*/site-packages/"$package"-*.dist-info
    rm -rf .venv/lib/python*/site-packages/"$package".libs
done

echo "Packing release files"
cp --recursive --no-preserve=ownership .venv/lib/python*/site-packages/* /output/

echo "all done!"
