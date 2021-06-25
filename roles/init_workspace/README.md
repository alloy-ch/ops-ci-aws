# Ansible Role: `init_workspace`

This Ansible role:
*  gathers some facts about the current git repository
*  creates a temporary folder within the OS standard temp folder
*  optionally creates a virtualenv role
*  optionally create a local `kubectl` context

## Parameters

| Param               | Mandatory |  Type   | Default | Description                                                                                                           |
|:--------------------|:---------:|:-------:|:--------|:----------------------------------------------------------------------------------------------------------------------|
| `python3_workspace` |    No     | boolean | `false` | When truthy, a Python3 virtualenv will be initialized inside `workspace_path`                                         |
| `use_eks`           |    No     | boolean | `false` | When truthy, adds a functioning context into local kubectl config for the EKS if the current environment is not `ops` |

## Outputs

| Ansible variable | Type | Description                     |
|:-----------------|:-----|:--------------------------------|
| `workspace_path` | str  | Path of the temporary workspace |
| `git_info`       | dict | See below for more details      |

`git_info` is a `dict` with the following key-pairs:
*  `repo_name`: name of the repository, without Github organization prefix
*  `branch_name`: current git branch
*  `commit_hash`: the full (40-chars) hash of the current HEAD
*  `commit_hash_short`: the beginning 7-chars of the hash
*  `has_pending_changes`: truthy if the current work directory is dirty
