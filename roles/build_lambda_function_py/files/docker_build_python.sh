#!/usr/bin/env bash

set -e
cd /var/runtime

# check that boto3 and botocore in pyproject.toml is the same as in the lambda runtime
runtime_boto3_version=$(python -c "import boto3;print(boto3.__version__)")
runtime_botocore_version=$(python -c "import botocore;print(botocore.__version__)")
pyproject_boto3_version=$(cat /workspace/pyproject.toml | grep boto3 | cut -d'=' -f2 | tr -d ' ' | tr -d '"')
pyproject_botocore_version=$(cat /workspace/pyproject.toml | grep botocore | cut -d'=' -f2 | tr -d ' ' | tr -d '"')

if [ "$runtime_boto3_version" != "$pyproject_boto3_version" ] || [ "$runtime_botocore_version" != "$pyproject_botocore_version" ]; then
    echo "boto3 and botocore versions in pyproject.toml and lambda runtime are not the same"
    echo "runtime: boto3==$runtime_boto3_version, botocore==$runtime_botocore_version"
    echo "pyproject.toml: boto3==$pyproject_boto3_version, botocore==$pyproject_botocore_version"
    exit 1
fi

cd /workspace
echo "Install poetry"
pip --quiet --disable-pip-version-check --no-color install --no-cache-dir "poetry>=1.0.0" toml
echo "Installing dependencies"
poetry config virtualenvs.create true
poetry config virtualenvs.in-project true
poetry install --without dev,from_lambda_layers,runtime --no-interaction --no-ansi --no-cache
echo "Packing release files"
cp --recursive --no-preserve=ownership .venv/lib/python*/site-packages/* /output/
packages=$(python -c "import toml;file=open('pyproject.toml');print(','.join(x['include'] for x in toml.load(file)['tool']['poetry']['packages']));file.close()")
for package in ${packages//,/ }
do
    cp --recursive --no-preserve=ownership ${package} /output/
done
rm -rf ./venv
pip  --quiet --disable-pip-version-check --no-color uninstall --yes poetry
echo "all done!"
