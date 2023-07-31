#!/usr/bin/env bash

set -e

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
