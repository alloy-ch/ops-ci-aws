# ops-ci-aws

**Current version: 1.0.6**

This repository holds the shared Ansible roles, modules and tasks for projects to be deployed into AWS. It creates an Ansible collection.

## Usage

Before we reach the state with high generalization and parameterization, this Ansible collection is not published to Galaxy. Instead, we
use the direct git approach.

To install the latest version from the default branch:
```shell-script
ansible-galaxy collection install git+https://github.com/ringier-data/ops-ci-aws.git
```

To install a specific tagged version:
```shell-script
ansible-galaxy collection install git+https://github.com/ringier-data/ops-ci-aws.git,r2.3.1
```

To install a specific git commit:
```shell-script
ansible-galaxy collection install git+https://github.com/ringier-data/ops-ci-aws.git,7b60ddc245bc416b72d8ea6ed7b799885110f5e5
```

## Troubleshooting

Ansible installs the collection by default to `~/.ansible/collections/`, make local modification there for debugging or troubleshooting.
