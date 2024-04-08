#!/usr/bin/env bash

set -e
cd /var/runtime

strict=false
only=""
with=""
without=""
packages=""
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
            echo "  -p, --packages <package1> <package2> ..."
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
        -p|--packages)
            # get all values next to the option
            shift
            while [[ $# -gt 0 ]] && ! [[ "$1" =~ ^- ]]; do
                if [ -z "$packages" ]; then
                    packages="$1"
                else
                    packages="$packages,$1"
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
pyproject_boto3_version=$(cat /workspace/pyproject.toml | grep '^boto3 ' | cut -d'=' -f2 | tr -d ' ' | tr -d '"')
pyproject_botocore_version=$(cat /workspace/pyproject.toml | grep '^botocore ' | cut -d'=' -f2 | tr -d ' ' | tr -d '"')

if [ "$runtime_boto3_version" != "$pyproject_boto3_version" ] || [ "$runtime_botocore_version" != "$pyproject_botocore_version" ]; then
    echo "boto3 and botocore versions in pyproject.toml and lambda runtime are not the same"
    echo "runtime: boto3==$runtime_boto3_version, botocore==$runtime_botocore_version"
    echo "pyproject.toml: boto3==$pyproject_boto3_version, botocore==$pyproject_botocore_version"
    if [ "$strict" = true ]; then
        exit 1
    fi
fi

cd /workspace
echo "Install poetry"
pip --quiet --disable-pip-version-check --no-color install --no-cache-dir "poetry>=1.0.0" toml
echo "Installing dependencies"
poetry config virtualenvs.create true
poetry config virtualenvs.in-project true
echo Installing dependencies, by running: 'poetry install "$@" --no-interaction --no-ansi --no-cache'
# construct the command
cmd="poetry install --no-interaction --no-ansi --no-cache"
if [ -n "$only" ]; then
    cmd="$cmd --only $only"
fi
if [ -n "$with" ]; then
    cmd="$cmd --with $with"
fi
if [ -n "$without" ]; then
    cmd="$cmd --without $without"
fi
# run the command
eval "$cmd"

# remove all dependencies that are pinned in the lambda layers
newline=$'\n'
lambda_packages=$(sed -n '/\[tool.poetry.group.from_lambda_layers.dependencies\]/,/^\[/{//!p;}' pyproject.toml | sed -e 's/ =.*//')
runtime_packages=$(sed -n '/\[tool.poetry.group.runtime.dependencies\]/,/^\[/{//!p;}' pyproject.toml | sed -e 's/ =.*//')
removable_packages="$lambda_packages$newline$runtime_packages"

echo "Removing pinned dependencies from site-packages"
for package in $removable_packages
do
    rm -rf .venv/lib/python*/site-packages/"$package"
    rm -rf .venv/lib/python*/site-packages/"$package"-*.dist-info
    rm -rf .venv/lib/python*/site-packages/"$package".libs
done

echo "Packing release files"
cp --recursive --no-preserve=ownership .venv/lib/python*/site-packages/* /output/
# if packages are empty then we copy all packages from pyproject.toml
if [ -z "$packages" ]; then
    packages=$(python -c "import toml;file=open('pyproject.toml');print(','.join(x['include'] for x in toml.load(file)['tool']['poetry']['packages']));file.close()")
fi
for package in ${packages//,/ }
do
    cp --recursive --no-preserve=ownership "${package}" /output/
done
echo "all done!"
