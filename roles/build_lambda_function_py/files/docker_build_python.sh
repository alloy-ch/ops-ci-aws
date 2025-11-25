#!/usr/bin/env bash

set -e

# Install git and ssh clients for private repository access
yum install -y git openssh-clients > /dev/null 2>&1

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

# Check that boto3 and botocore versions match between project file and lambda runtime
cd /var/runtime
runtime_boto3_version=$(python -c "import boto3;print(boto3.__version__)")
runtime_botocore_version=$(python -c "import botocore;print(botocore.__version__)")

cd /workspace

# Auto-detect package manager
if [ -f "uv.lock" ]; then
    package_manager="uv"
elif [ -f "poetry.lock" ]; then
    package_manager="poetry"
else
    echo "Error: Cannot detect package manager. No uv.lock or poetry.lock found."
    exit 1
fi

echo "Using package manager: $package_manager"

if [ "$package_manager" = "uv" ]; then
    # UV format: "boto3==1.26.90"
    pyproject_boto3_version=$(cat /workspace/pyproject.toml | grep '"boto3==' | cut -d'=' -f3 | cut -d'"' -f1)
    pyproject_botocore_version=$(cat /workspace/pyproject.toml | grep '"botocore==' | cut -d'=' -f3 | cut -d'"' -f1)
else
    # Poetry format: boto3 = "1.26.90"
    pyproject_boto3_version=$(cat /workspace/pyproject.toml | grep '^boto3 ' | cut -d'=' -f2 | tr -d ' ' | tr -d '"')
    pyproject_botocore_version=$(cat /workspace/pyproject.toml | grep '^botocore ' | cut -d'=' -f2 | tr -d ' ' | tr -d '"')
fi

if [ "$runtime_boto3_version" != "$pyproject_boto3_version" ] || [ "$runtime_botocore_version" != "$pyproject_botocore_version" ]; then
    echo "boto3 and botocore versions in pyproject.toml and lambda runtime are not the same"
    echo "runtime: boto3==$runtime_boto3_version, botocore==$runtime_botocore_version"
    echo "pyproject.toml: boto3==$pyproject_boto3_version, botocore==$pyproject_botocore_version"
    if [ "$strict" = true ]; then
        exit 1
    fi
fi

# Install package manager and dependencies
if [ "$package_manager" = "uv" ]; then
    echo "Install uv < 1.0.0 and toml"
    pip --quiet --disable-pip-version-check --no-color install --no-cache-dir "uv<1.0.0" toml
    
    echo "Installing dependencies with uv"
    # construct the command
    cmd="uv sync --no-dev --no-install-project"
    if [ -n "$only" ]; then
        # split by comma an loop through each group
        IFS=',' read -ra groups <<< "$only"
        for group in "${groups[@]}"; do
            cmd="$cmd --only-group $group"
        done
    fi
    if [ -n "$with" ]; then
        # split by comma an loop through each group
        IFS=',' read -ra groups <<< "$with"
        for group in "${groups[@]}"; do
            cmd="$cmd --group $group"
        done
    fi
    if [ -n "$without" ]; then
        # split by comma an loop through each group
        IFS=',' read -ra groups <<< "$without"
        for group in "${groups[@]}"; do
            cmd="$cmd --no-group $group"
        done
    fi
else
    echo "Install poetry"
    pip --quiet --disable-pip-version-check --no-color install --no-cache-dir "poetry>=1.0.0" toml
    
    echo "Installing dependencies with poetry"
    poetry config virtualenvs.create true
    poetry config virtualenvs.in-project true
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
fi

echo "Running: $cmd"
eval "$cmd"

# Extract dependencies to remove based on package manager
site_packages_path=".venv/lib/python*/site-packages"
if [ "$package_manager" = "uv" ]; then
    lambda_packages=($(uv export --format requirements.txt --only-group from-lambda-layers --no-annotate --no-header --no-hashes | sed -e 's/==.*//'))
    if [ "$strict" = true ]; then
        runtime_packages=($(uv export --format requirements.txt --only-group runtime --no-annotate --no-header --no-hashes | sed -e 's/==.*//'))
    else
        runtime_packages=()
    fi
else
    # For Poetry, get dependencies from tool.poetry.group sections
    lambda_packages=($(sed -n '/\[tool.poetry.group.from_lambda_layers.dependencies\]/,/^\[/{//!p;}' pyproject.toml | sed -e 's/ =.*//'))
    if [ "$strict" = true ]; then
        runtime_packages=($(sed -n '/\[tool.poetry.group.runtime.dependencies\]/,/^\[/{//!p;}' pyproject.toml | sed -e 's/ =.*//'))
    else
        runtime_packages=()
    fi
fi

removable_packages=("${lambda_packages[@]}" "${runtime_packages[@]}")

echo "Removing pinned dependencies from site-packages"
if [ "$strict" = true ]; then
    echo "Strict mode: removing both lambda layer and runtime packages"
else
    echo "Non-strict mode: removing only lambda layer packages (keeping runtime packages like boto3/botocore)"
fi
for package in "${removable_packages[@]}"
do
    rm -rf ${site_packages_path}/"$package"
    rm -rf ${site_packages_path}/"$package"-*.dist-info
    rm -rf ${site_packages_path}/"$package".libs
done

echo "Packing release files"
cp --recursive --no-preserve=ownership ${site_packages_path}/* /output/

# if packages are empty then we copy all packages from pyproject.toml
# TODO: this section feels not really necessary if we would use the dot notation to reference the handler,
#       e.g. `lambda_handler.index.handler` instead of `lambda_handler/index.handler` we just keep it for
#       backward compatibility for poetry projects only
if [ -z "$packages" ]; then
    if [ "$package_manager" = "poetry" ]; then
        # For Poetry projects - extract from [tool.poetry.packages]
        packages=$(python -c "import toml;file=open('pyproject.toml');print(','.join(x['include'] for x in toml.load(file)['tool']['poetry']['packages']));file.close()")
    elif [ "$package_manager" = "uv" ]; then
        # For UV projects - extract from [tool.hatch.build.targets.wheel] or [tool.hatch.build.targets.sdist]
        packages=$(python -c "
import toml
try:
    with open('pyproject.toml') as f:
        data = toml.load(f)
    # Try wheel first, then sdist as fallback
    if 'tool' in data and 'hatch' in data['tool'] and 'build' in data['tool']['hatch']:
        targets = data['tool']['hatch']['build'].get('targets', {})
        includes = targets.get('wheel', {}).get('include', []) or targets.get('sdist', {}).get('include', [])
        print(','.join(includes))
    else:
        print('')
except Exception:
    print('')
")
    fi
fi

for package in ${packages//,/ }
do
    # Check if package already exists in site-packages (to avoid duplication)
    if [ -d "${site_packages_path}/${package}" ]; then
        echo "Package '$package' already exists in site-packages, skipping copy"
    else
        echo "Copying package '$package' from source"
        cp --recursive --no-preserve=ownership "${package}" /output/
    fi
done

echo "all done!"
