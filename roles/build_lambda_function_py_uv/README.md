# Ansible Role: `build_lambda_function_py_uv`

This Ansible role makes a Python app ready for Lambda function using **uv** instead of poetry for dramatically improved build performance.

The Python application requires to be defined through a `pyproject.toml` file with uv-compatible dependency groups and the `uv.lock` file must be git tracked.

## Project Setup

The minimal setup requires a `pyproject.toml` file with the following sections:

### Using PEP 735 dependency-groups (Recommended)

```toml
[project]
name = "contents-realtime-processor"
version = "0.1.1"
description = "Contents Realtime Processor"
authors = [{name = "Ringier AG", email = "info@ringier.ch"}]
requires-python = ">=3.10, <3.11"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.sdist]
include = [
    "/src",
    "/README.md",
    "/LICENSE",
]

[tool.hatch.build.targets.wheel]
packages = ["src/contents_realtime_processor"]

[project.dependencies]
# Main dependencies here

[dependency-groups]
runtime = [  # match the runtime, see https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
    "boto3==1.26.90",
    "botocore==1.29.90",
]
dev = ["pytest", "black", "mypy"]
test = ["pytest-cov"]
from-lambda-layers = []  # managed by the role
```

## Local Package Handling

With `uv sync`, your local project package is automatically installed into the virtual environment's site-packages. This means you can reference any handler or module using standard Python dot notation:

- `lambda_handler.main` 
- `my_package.utils.helper_function`

No additional configuration is needed - everything gets packaged automatically.

## Dependency Group Handling

In case `lambda_layers_to_pin` is not empty, this role will check if the `pyproject.toml` file is up-to-date by trying to install the dependencies from the layers into the group `from_lambda_layers` and comparing the resulted `uv.lock` file with the git tracked one.

In order to keep the dependencies installed in the lambda function minimal, the following groups will always be ignored by default:
- `runtime` - Runtime dependencies provided by Lambda
- `from-lambda-layers` - Dependencies provided by Lambda layers  
- `dev` - Development dependencies
- `test`/`tests` - Testing dependencies
- `types` - Type checking dependencies

**Note**: Dependency group names use hyphens (e.g., `from-lambda-layers`) in TOML files, but uv commands can reference them with either hyphens or underscores.

## Parameters

| Param                                | Mandatory | Type | Default                       | Description                                                                       |
|:-------------------------------------|:---------:|:----:|:------------------------------|:----------------------------------------------------------------------------------|
| `source_path`                        |    No     | str   | `{{ playbook_dir }}/../app`         | Dir of the Python app, where the corresponding `pyproject.toml` is located.    |
| `lambda_runtime_docker_image_python` |    No     | str   | `public.ecr.aws/lambda/python:3.10` | Docker image to use for the build. Refer to [the definition](./defaults/main.yml) |
| `lambda_layers_to_pin`               |    No     | array | `[]`                                | Lambda layers that will be used to check whether the pyproject.toml file is up-to-date |
| `update_non_pinned_deps`             |    No     | bool  | `true`                              | Whether dependencies from lambda layers without version pins should be added/updated |
| `uv_groups_without`                  |    No     | array | `['dev', 'from-lambda-layers', 'runtime', 'types', 'test', 'tests']`           | List of groups to ignore when installing dependencies |
| `uv_groups_with`                     |    No     | array | `[]`                                | List of groups to include when installing dependencies |
| `uv_groups_only`                     |    No     | array | `[]`                                | List of groups to install exclusively, ignoring all others |
| `strict`                             |    No     | bool  | `true`                              | Whether to fail if boto3 and botocore are not pinned to match the lambda runtime |

## Outputs

| Variable           | Type | Description                                   |
|:-------------------|:----:|:----------------------------------------------|
| `lambda_code_path` | str  | Absolute path to the generated lambda code directory |
