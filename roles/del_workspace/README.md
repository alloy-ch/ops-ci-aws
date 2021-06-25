# Ansible Role: `del_workspace`

As the counterpart of role `init_workspace`, this Ansible role deleted the temporary folder created earlier.

## Parameters

| Param            | Mandatory | Type | Default | Description                                                                               |
|:-----------------|:---------:|:----:|:--------|:------------------------------------------------------------------------------------------|
| `workspace_path` |    No     | str  | `false` | Path of the temporary workspace, the same variable name as the output of `init_workspace` |

## Outputs

None
