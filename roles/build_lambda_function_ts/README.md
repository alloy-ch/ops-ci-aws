# Ansible Role: `build_lambda_function_ts`

This Ansible role makes a TypeScript app ready for Lambda function.

Some npm packages uses native binaries executables therefore are runtime OS specific. To make it work for lambda function, we build the
TypeScript app inside an AWS Lambda function runtime Docker container, so that the `npm install` picks up (or build locally) the right
binary architecture.

## Parameters


| Param                                | Mandatory | Type | Default                       | Description                                                                       |
|:-------------------------------------|:---------:|:----:|:------------------------------|:----------------------------------------------------------------------------------|
| `source_path`                        |    No     | str  | `{{ playbook_dir }}/../app`   | Dir of the TypeScript app, where the corresponding`package.json` is located.      |
| `lambda_runtime_docker_image_nodejs` |    No     | str  | `amazon/aws-lambda-nodejs:16` | Docker image to use for the build. Refer to [the definition](./defaults/main.yml) |

## Outputs


| Ansible variable   | Type | Description                                                                    |
|:-------------------|:-----|:-------------------------------------------------------------------------------|
| `lambda_code_path` | str  | Dir of the output, ready to pass over to CloudFormation for SAM transformation |

## Examples

```ansible
- name: 'build the TypeScript application at ./app for Lambda'
- include_role:
    name: 'ringier.aws_cicd.build_lambda_function_ts'

- name: 'show result'
  debug:
    msg: '{{ lambda_code_path }}'

#> /var/folders/5n/br0vjgz51vg46vtsn_81mpb40000gn/T/ansible.vmn2dzop.iris/lambda_2d6d9acb7b634c4f5aaa00d19ec6c05f

- name: 'build the TypeScript application at ./app/component1/function2 for Lambda'
  include_role:
    name: 'ringier.aws_cicd.build_lambda_function_ts'
  vars:
    source_path: '../app/component1/function2'

- name: 'show result'
  debug:
    msg: '{{ lambda_code_path }}'

#> /var/folders/5n/br0vjgz51vg46vtsn_81mpb40000gn/T/ansible.3llnq9tn.iris/lambda_803d439027c50820fc5d47105fa363a4
```
