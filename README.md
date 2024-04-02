# ops-ci-aws

**Current version: v2.3.1**

This repository holds the shared Ansible roles, modules and tasks for projects to be deployed into AWS. It creates an Ansible collection.

## Content

### Ansible modules

*  [gather_stack_outputs](./plugins/modules/README.md)

### Ansible roles

*  [build_lambda_function_ts](./roles/build_lambda_function_ts/README.md)
*  [build_lambda_function_py](./roles/build_lambda_function_py/README.md)
*  [build_push_docker_image](./roles/build_push_docker_image/README.md)
*  [create_acm_ssl_certificate](./roles/create_acm_ssl_certificate/README.md)
*  [create_db_user](./roles/create_db_user/README.md)
*  [del_workspace](./roles/del_workspace/README.md)
*  [deploy_to_k8s](./roles/deploy_to_k8s/README.md)
*  [init_workspace](./roles/init_workspace/README.md)
*  [run_cloudformation](./roles/run_cloudformation/README.md)


## Usage

### Install

Before we reach the state with high generalization and parameterization, this Ansible collection is not published to Galaxy. Instead, we
use the direct git approach.

To install the latest version from the default branch:
```shell-script
ansible-galaxy collection install --force git+https://github.com/alloy-ch/ops-ci-aws.git
```

To install a specific tagged version:
```shell-script
ansible-galaxy collection install --force git+https://github.com/alloy-ch/ops-ci-aws.git,v2.3.1
```

To install a specific git commit:
```shell-script
ansible-galaxy collection install --force git+https://github.com/alloy-ch/ops-ci-aws.git,7b60ddc245bc416b72d8ea6ed7b799885110f5e5
```
A note for all the `ansible-galaxy collection install` examples above: `ansible-galaxy` itself does not handle the upgrade if the remote
collection has a higher version than the locally installed one, according to [this Github issue](https://github.com/ansible/ansible/issues/65699).
To overcome this problem, either we use `--force` to *always* overwrite the local installation no matter whether the version is newer or
older, or we use `--upgrade` to "force" the installation if (and only if) the remote version is newer than the local one.

### Config

A typical Ansible playbook looks like:

```yaml
---
  - name: 'create CodeBuild projects'  # meaningful name defines the repo
    hosts: 'localhost'    # always localhost, we do not use the remote agent setup of Ansible 
    connection: 'local'   # always local
    collections: 'ringier.aws_cicd'   # tell Ansible to use this collection
    gather_facts: false   # we only gather some needed facts 
    vars:
      aws_region: 'eu-central-1'    # where the deployment target is located
      project_id: 'rcplus'          # project code. In our terminology, "project" is a very big thing (normally multi-year-multi-million)
      project_version: 1.0.3        # semver of the repo. Normally managed by PyPI package `bumpsemver`. NOTE: do NOT put any version prefix here
      software_component: 'devops'  # a code to help identify the purpose of repo. e.g. `basis`, `iris`, `foobar` etc.  
    pre_tasks:
      - fail: msg='specify an environment (dev, stg, prod, ops)'
        when: env not in ['dev', 'stg', 'prod', 'ops']
      - include_vars: 'environment_vars/{{ env }}.yml'
    roles:
      - 'init_workspace'  # normally the very first role of a playbook
      - 'configure-ci'    # do the repo specific deployment logic here
      - 'del_workspace'   # normally the very last role of a playbook 
```

## Troubleshooting

Ansible installs the collection by default to `~/.ansible/collections/`, make local modification there for debugging or troubleshooting.
