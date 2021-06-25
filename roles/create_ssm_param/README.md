# Ansible Role: `init_workspace`

**DEPRECATED** Do not use this role anymore.

This Ansible role creates an SSM secure string parameter by getting the value from the environment variable.

## Examples
```ansible
- role:
    name: create-ssm-param
  vars:
    name: "/dev/scmi/some-component/db.username"
    description: "Some detailed description"
    environment_var: "CMI_SOME_COMPONENT_DB_USERNAME"
```
