# Ansible Role: `build_lambda_function_py`

This Ansible role makes a Python app ready for Lambda function deployment, with unified support for both Poetry and UV package managers.

## Package Manager Support

This role automatically detects and works with both Poetry and UV package managers:
- **Poetry**: Detected by the presence of `poetry.lock` file
- **UV**: Detected by the presence of `uv.lock` file

The role maintains backward compatibility - existing Poetry-based playbooks will continue to work unchanged.

## Project Structure Requirements

### Poetry Projects
The Python application requires a `pyproject.toml` file with Poetry configuration and the `poetry.lock` file must be git tracked.

```toml
[tool.poetry]
version = "0.1.1"
name = "contents-realtime-processor"
description = "Contents Realtime Processor"
authors = ["Ringier AG <info@ringier.ch>"]
packages = [{include = "lambda_handler"}]

[build-system]
requires = ["poetry-core"]
build-backend = "poetry.core.masonry.api"

[tool.poetry.dependencies]
python = ">=3.10, <3.11"  # match the runtime

[tool.poetry.group.runtime.dependencies]  # match the runtime, see https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
boto3 = "1.26.90"
botocore = "1.29.90"
```

### UV Projects
For UV projects, the `pyproject.toml` file should follow UV conventions and the `uv.lock` file must be git tracked.

```toml
[project]
name = "contents-realtime-processor"
version = "0.1.1"
description = "Contents Realtime Processor"
authors = [{name = "Ringier AG", email = "info@ringier.ch"}]
dependencies = [
    "python>=3.10,<3.11",  # match the runtime
]

[dependency-groups]
runtime = [  # match the runtime, see https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
    "boto3==1.26.90",
    "botocore==1.29.90",
]
```

## Dependency Management

In case `lambda_layers_to_pin` is not empty, this role will check if the `pyproject.toml` file is up-to-date by
trying to install the dependencies from the layers and comparing the resulted lock file with the git tracked one.

### Excluded Groups
To keep the dependencies installed in the lambda function minimal, the following groups will always be ignored:

**Poetry projects:**
- `[tool.poetry.group.runtime.dependencies]`
- `[tool.poetry.group.from_lambda_layers.dependencies]`
- `[tool.poetry.group.dev.dependencies]`

**UV projects:**
- `[dependency-groups.runtime]`
- `[dependency-groups.from_lambda_layers]`
- `[dependency-groups.dev]`


## Parameters

| Param                                | Mandatory | Type | Default                       | Description                                                                       |
|:-------------------------------------|:---------:|:----:|:------------------------------|:----------------------------------------------------------------------------------|
| `source_path`                        |    No     | str   | `{{ playbook_dir }}/../app`         | Dir of the Python app, where the corresponding `pyproject.toml` is located.    |
| `lambda_runtime_docker_image_python` |    No     | str   | `public.ecr.aws/lambda/python:3.10` | Docker image to use for the build. Refer to [the definition](./defaults/main.yml) |
| `lambda_layers_to_pin`               |    No     | array | `[]`                                | Lambda layers that will be used in order to check whether the pyproject.toml file is up-to-date |
| `update_non_pinned_deps`             |    No     | bool  | `true`                              | Whether the dependencies from the lambda layers for those it is not possible to resolve a version should be added/updated by the role |
| `groups_without`                     |    No     | array | `['dev', 'from_lambda_layers', 'runtime', 'types', 'test', 'tests']`           | List of dependency groups to ignore when installing dependencies |
| `groups_with`                        |    No     | array | `[]`                                | List of dependency groups to install when installing dependencies |
| `groups_only`                        |    No     | array | `[]`                                | List of dependency groups to install, ignoring all others |
| `poetry_without`                     |    No     | array | *References `groups_without`*       | **Deprecated**: Use `groups_without` instead. Legacy Poetry parameter for backward compatibility |
| `poetry_with`                        |    No     | array | *References `groups_with`*          | **Deprecated**: Use `groups_with` instead. Legacy Poetry parameter for backward compatibility |
| `poetry_only`                        |    No     | array | *References `groups_only`*          | **Deprecated**: Use `groups_only` instead. Legacy Poetry parameter for backward compatibility |
| `strict`                             |    No     | bool  | `true`                              | Whether to fail if boto3 and botocore are not pinned to the same version as the ones used in the lambda runtime |
| `packages`                           |    No     | array | `[]`                                | List of packages to install in the lambda function. If empty, all the packages will be installed |

### Parameter Migration Guide

**Recommended approach**: Use the new generic parameters (`groups_*`) for all new playbooks:

```yaml
# New recommended parameters
groups_without: ['dev', 'test']
groups_with: ['extra', 'optional']
groups_only: ['main', 'prod']
```

**Legacy support**: Existing playbooks using Poetry parameters will continue to work:

```yaml
# Legacy parameters (still supported but deprecated)
poetry_without: ['dev', 'test']
poetry_with: ['extra', 'optional']
poetry_only: ['main', 'prod']
```

## Outputs


| Ansible variable   | Type | Description                                                                    |
|:-------------------|:-----|:-------------------------------------------------------------------------------|
| `lambda_code_path` | str  | Dir of the output, ready to pass over to CloudFormation for SAM transformation |

## Examples

### Basic Usage (Auto-detects Poetry or UV)

```ansible
- name: 'build the Python application at ./app for Lambda'
  include_role:
    name: 'ringier.aws_cicd.build_lambda_function_py'

- name: 'show result'
  debug:
    msg: '{{ lambda_code_path }}'

#> /var/folders/5n/br0vjgz51vg46vtsn_81mpb40000gn/T/ansible.vmn2dzop.iris/lambda_2d6d9acb7b634c4f5aaa00d19ec6c05f
```

### Custom Source Path

```ansible
- name: 'build the Python application at ./app/component1/function2 for Lambda'
  include_role:
    name: 'ringier.aws_cicd.build_lambda_function_py'
  vars:
    source_path: '../app/component1/function2'

- name: 'show result'
  debug:
    msg: '{{ lambda_code_path }}'

#> /var/folders/5n/br0vjgz51vg46vtsn_81mpb40000gn/T/ansible.3llnq9tn.iris/lambda_803d439027c50820fc5d47105fa363a4
```

### Using Group Parameters (Recommended - Works for both Poetry and UV)

```ansible
- name: 'build Python app with specific groups'
  include_role:
    name: 'ringier.aws_cicd.build_lambda_function_py'
  vars:
    groups_with: ['extra', 'optional']
    groups_without: ['dev', 'test']
    # Works automatically for both Poetry and UV projects
```

### Legacy Poetry Parameters (Deprecated but still supported)

```ansible
- name: 'build Python app with legacy Poetry parameters'
  include_role:
    name: 'ringier.aws_cicd.build_lambda_function_py'
  vars:
    poetry_with: ['extra', 'optional']
    poetry_without: ['dev', 'test']
    # These still work but are deprecated - use groups_* instead
```
