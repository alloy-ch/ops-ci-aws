# Ansible Role: `build_lambda_function_py`

This Ansible role makes a Python app ready for Lambda function.

The Python application requires to be defined through poetry and the `poetry.lock` file must be git tracked.

The minimal setup requires a `pyproject.toml` file with the following sections:

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

In case `lambda_layers_to_pin` is not empty this role will check if the `pyproject.toml` file is up-to-date, by
trying to install the dependencies from the layers into the group `from_lambda_layers` and comparing the resulted
`poetry.lock` file with the git tracked one.

In order to keep the dependencies installed in the lambda function minimal the following groups will always be ignored:
- `[tool.poetry.group.runtime.dependencies]`
- `[tool.poetry.group.from_lambda_layers.dependencies]`
- `[tool.poetry.group.dev.dependencies]`


## Parameters


| Param                                | Mandatory | Type | Default                       | Description                                                                       |
|:-------------------------------------|:---------:|:----:|:------------------------------|:----------------------------------------------------------------------------------|
| `source_path`                        |    No     | str   | `{{ playbook_dir }}/../app`         | Dir of the TypeScript app, where the corresponding`package.json` is located.    |
| `lambda_runtime_docker_image_python` |    No     | str   | `public.ecr.aws/lambda/python:3.10` | Docker image to use for the build. Refer to [the definition](./defaults/main.yml) |
| `lambda_layers_to_pin`               |    No     | array | `[]`                                | Lambda layers that will be used in order to check whether the pyproject.yml file is up-to-date |
| `update_non_pinned_deps`             |    No     | bool  | `true`                                | Whether the dependencies from the lambda layers for those it is not possible to resolve a version should be added/updated by the role |

## Outputs


| Ansible variable   | Type | Description                                                                    |
|:-------------------|:-----|:-------------------------------------------------------------------------------|
| `lambda_code_path` | str  | Dir of the output, ready to pass over to CloudFormation for SAM transformation |

## Examples

```ansible
- name: 'build the TypeScript application at ./app for Lambda'
- include_role:
    name: 'ringier.aws_cicd.build_lambda_function_py'

- name: 'show result'
  debug:
    msg: '{{ lambda_code_path }}'

#> /var/folders/5n/br0vjgz51vg46vtsn_81mpb40000gn/T/ansible.vmn2dzop.iris/lambda_2d6d9acb7b634c4f5aaa00d19ec6c05f

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
