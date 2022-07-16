# Ansible Role: `run_cloudformation`

This is highly complicated Ansible role. It:
*  templates out the CloudFormation template potentially written as a Jinja2 template
*  checks if it is a classical CloudFormation template, or a SAM template
*  if it is a SAM template, transforms it to the classical one
*  moves the template from local to a S3 bucket
*  creates or updates the CloudFormation stack using the template from S3 bucket

Enabling Jinja template by default simplifies the CloudFormation template authoring, because we do not always need to pass over those
common variables as CloudFormation Parameters (e.g. `project_version`, `project_id`, etc.), and we can do much more flexible
`if...then...else` within CloudFormation template.

Unifying the classical and SAM templates into one role helps to remove the redundant code, and encourages our engineers to use the
serverless design patterns.

Uploading the template to S3 before applying it removes the size limit at 51'200 bytes of one CloudFormation template.

## Parameters

| Param                            | Mandatory | Type | Default              | Description                                                                                                                                                                                      |
|:---------------------------------|:---------:|:----:|:---------------------|:-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `region`                         |    NO     | str  | `'{{ aws_region }}'` | The region to which the CloudFormation template is deployed. In the most cases it should not be specified. Only use it in rare cases to handle the stacks for CloudFront at us-east-1            |
| `template_parameters`            |    No     | dict | -                    | CloudFormation template Parameters to pass over to the deployment                                                                                                                                |
| `infrastructure_bucket_override` |    No     | str  | ``                   | Specify the S3 bucket to store the rendered CloudFormation template. This parameter **SHOULD ONLY BE USED** for the initial bootstrap repo to create the permanent S3 bucket for infrastructure. |
| `template`                       |    Yes    | str  | -                    | Filepath to the CloudFormation template, use Jinja2 templating grammar if it makes things easier.                                                                                                |
| `stack_name`                     |    Yes    | str  | -                    | Name of the CloudFormation stack to be created.                                                                                                                                                  |
| `skip_version_tag`               |    No     | bool | false                | When true, the CloudFormation stack will not have `Version` tag.                                                                                                                                 |
| `version_tag_override`           |    No     | str  | -                    | When specified, the CloudFormation stack will have `Version` tagged with the specified value instead of the default `{{ version }}`. This parameter overrules `skip_version_tag`.                |
| `repo_tag_override`              |    No     | str  | -                    | When specified, the CloudFormation stack will have `Repository` tagged with the specified value instead of the default `{{ git_info.repo_name }}`.                                               |

Regarding `version_tag_override` and `repo_tag_override`, we have some common roles
(e.g. [ship_logs_to_logzio](../ship_logs_to_logzio/README.md)) create potentially multiple "instances" within the same AWS account.
We need it to keep some tags stable instead of always inheriting the tags set from the repo referring this role. 

Regarding `version_tag_override`, for the override value, if the semver is used, do not forget the prefix `v`. e.g. to tag `1.5.5` please specify `v1.5.5`

## Outputs

None

## Examples

```ansible
# Refer to the example of [`deploy_to_k8s`](../deploy_to_k8s/README.md) about why we need set_fact first
- set_fact:
    cf_ecr_template: '{{ role_path }}/files/cf-ecr.yml'

- name: 'setup and login to ECR registry'
  set_fact:
    ecr_stack_name: '{{ ecr_repository_name }}-ecr'
- include_role:
    name: 'ringier.aws_cicd.run_cloudformation'
  vars:
    stack_name: '{{ ecr_stack_name }}'
    template: '{{ cf_ecr_template }}'


- set_fact:
    template_file: '{{ role_path }}/files/eks_template.yml'

- name: 'create AWS EKS cluster'
  include_role:
    name: 'ringier.aws_cicd.run_cloudformation'
  vars:
    stack_name: '{{ env }}-{{ project_id }}-eks-cluster'
    template: '{{ template_file }}'
    template_parameters:
      ClusterName: '{{ eks_cluster_name }}'
      VpnCidr: '{{ ops_shared_vpc_cidr }}'
      VpcCidr: '{{ net_vpc }}'
      EksLogsRetentionInDays: '{{ eks_log_retention_in_days }}'
```
