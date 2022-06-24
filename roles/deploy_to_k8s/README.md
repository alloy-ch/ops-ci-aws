# Ansible Role: `deploy_to_k8s`

This Ansible role:
*  takes a Kubernetes configuration manifest file potentially written as a Jinja2 template
*  applies the Jinja2 templating to make it a Kubernetes ready config file
*  applies the config file to the EKS cluster by `kubectl`

## Parameters

| Param           | Mandatory | Type | Default | Description                                                                            |
|:----------------|:---------:|:----:|:--------|:---------------------------------------------------------------------------------------|
| `cluster_arn`   |    Yes    | str  | -       | Arn of the EKS cluster, e.g. `arn:aws:eks:eu-west-1:965749599769:cluster/dev-scmi-eks` |
| `template_file` |    Yes    | str  | -       | Filepath to the local Kubernetes manifest yaml file to deploy                          |

## Outputs

None

## Examples

```ansible
- set_fact:
    k8s_manifest_file: '{{ role_path }}/files/scheduler-manifest.yml'

- name: 'deploy the scheduler application to k8s cluster'
  include_role:
    name: 'ringier.aws_cicd.deploy_to_k8s'
  vars:
    cluster_arn: '{{ eks_stack.outputs.EksArn }}'
    template_file: '{{ k8s_manifest_file }}'
```

**NOTE**
In development practice, `{{ role_path }}` can be a tricky topic because of the variable scope concept of Ansible. For the example
above, if we do
```yaml
- name: 'deploy the scheduler application to k8s cluster'
  include_role:
    name: 'ringier.aws_cicd.deploy_to_k8s'
  vars:
    cluster_arn: '{{ eks_stack.outputs.EksArn }}'
    template_file: '{{ role_path }}/files/scheduler-manifest.yml'
```
The `role_path` is actually the path of `deploy_to_k8s` role, not the desired application role. Therefore, we eval the real
application path beforehand with an extra `set_fact`.

