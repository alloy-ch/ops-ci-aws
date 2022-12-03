# Ansible modules

## `gather_stack_outputs`

This Ansible module retrieves the stack outputs of a given CloudFormation stack and stores the outputs in an Ansible variable as a dict.

NOTE: we get all the outputs of a stack, no matter the output is exported or not.

### Example

With the following Ansible task:
```ansible
  - name: 'get storage stack'
    ringier.aws_cicd.gather_stack_outputs:
      stack_name: 'prod-sherlock-api-storage'
      region: 'eu-central-1'
    register: storage_stack
```
on CloudFormation stack `prod-sherlock-api-storage`:
![cfn stack outputs](../../doc_images/cfn_stack_outputs.png)

We can use the value at the subsequent tasks like:

```ansible
- debug: msg='{{ storage_stack.outputs.CacheHost }}'
  
- debug: msg= '{{ storage_stack.outputs.CachePort }}' 
```

## `ssm_parameter`

This ansible module creates/updates/deletes an SSM Parameter.

It is based on https://docs.ansible.com/ansible/devel//collections/community/aws/ssm_parameter_module.html and additionally supports
tagging the parameter in the same Ansible task.

NOTE:
1. Changing the tags (both keys/Name and values/Value) does not result in the `changed` status of an Ansible task
2. Inside the module it calculates the delta of tags key. Therefore, to delete all tags of a parameter, just specify `tags: {}`.
   Of course we don't (/can't) touch those keys (/tag Name) start with `aws:`

### Example

```ansible
  - name: 'set SSM parameter for the connection'
    ringier.aws_cicd.ssm_parameter:
      region: '{{ aws_region }}'
      name: '/alloy/aireflow/aws_default'
      value: '{ "conn_type": "aws" }'
      description: '[Airflow Connection] AWS Default: To reuse the EC2 instance profile'
      overwrite_value: 'changed'
      string_type: 'String'
      key_id: 'alias/gov-rcplus-devops-secrets'
      tags:
        Name: '{{ env }}-{{ project_id }}-{{ software_component }}-conn-aws-default'
        Project: '{{ project_id }}'
        Environment: '{{ env }}'
        Repository: '{{ git_info.repo_name }}'
        Version: '{{ project_version }}'
```
