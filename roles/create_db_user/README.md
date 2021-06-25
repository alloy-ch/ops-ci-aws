# Ansible Role: `create_db_user`

This Ansible role:
*  creates a user at the PostgreSQL database, with the permissions defined in the parameters (or the default values)
*  stores the username at SSM ParameterStore as a String
*  stores the password at SSM ParameterStore as a SecureString

**NOTE:** If the user exists, the Role does not change anything.

## Parameters

| Param                                     |  Mandatory  | Type | Default                                                            | Description                                                                                                                                                                                             |
|:------------------------------------------|:-----------:|:----:|:-------------------------------------------------------------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `software_component`                      |     Yes     | str  | -                                                                  | It contributes to many identifiers, e.g. the CloudFormation stacks named as {{ env }}-{{ project_id }}-{{ software_component }}-rds, will be rendered to `dev-scmi-crawler-rds.`                        |
| `ssmkey_rds_master_username_key`          |     No      | str  | `'/{{ project_id }}/{{ software_component }}/rds/master-username'` | Name of the SSM Parameter to store RDS master username.                                                                                                                                                 |
| `ssmkey_rds_master_password_key`          |     No      | str  | `'/{{ project_id }}/{{ software_component }}/rds/master-password'` | Name of the SSM Parameter to store RDS master password.                                                                                                                                                 |
| `rds_endpoint_cloudformation_export_name` | Conditional | str  | -                                                                  | Mutually exclusive with `rds_endpoint`. Specify the CloudFormation stack export name of the RDS endpoint. e.g. `scmi-{{ software_component }}-rds-endpoint`                                             |
| `rds_endpoint`                            | Conditional | str  | -                                                                  | Mutually exclusive with `rds_endpoint_cloudformation_export_name`. Specify the RDS endpoint (without protocol and port) e.g. `dev-scmi-crawler-aurora.cluster-c2qxetkc4ajc.eu-west-1.rds.amazonaws.com` |
| `rds_db_name`                             |     No      | str  | `{{ project_id }}`                                                 | Database name at PostgreSQL. As we usually have one cluster hosts only one database, naming uniqueness does not bring additional benefit.                                                               |
| `rds_schema_name`                         |     No      | str  | `{{ rds_db_name }}`                                                | Schema name inside DB at PostgreSQL.                                                                                                                                                                    |
| `rds_port`                                |     No      | str  | `'5432'`                                                           | TCP port of PostgreSQL. Without special reason it should not be changed.                                                                                                                                |
| `app_db_username`                         |     Yes     | str  | -                                                                  | Name of the PostgreSQL role to be created. e.g. `scmi_change_monitor_user`                                                                                                                              |
| `ssmkey_rds_app_user_username_key`        |     Yes     | str  | -                                                                  | Key of the SSM Parameter to store the username. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                                                      |
| `ssmkey_rds_app_user_password_key`        |     Yes     | str  | -                                                                  | Key of the SSM Parameter to securely store the password. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                                             |
| `database_privileges`                     |     No      | str  | `'CONNECT,TEMP'`                                                   | Privileges to be granted to the new user on database.                                                                                                                                                   |
| `schema_privileges`                       |     No      | str  | `'USAGE'`                                                          | Privileges to be granted to the new user on schema.                                                                                                                                                     |
| `sequence_privileges`                     |     No      | str  | `'ALL PRIVILEGES'`                                                 | Privileges to be granted to the new user on sequence.                                                                                                                                                   |
| `table_privileges`                        |     No      | str  | `'SELECT,UPDATE,DELETE,INSERT'`                                    | Privileges to be granted to the new user on table.                                                                                                                                                      |
| `function_privileges`                     |     No      | str  | `'ALL PRIVILEGES'`                                                 | Privileges to be granted to the new user on function.                                                                                                                                                   |

## Outputs

None

## Examples

```ansible
- include_role:
    name: 'create_db_user'
  vars:
    rds_endpoint_cloudformation_export_name: '{{ project_id }}-{{ software_component }}-rds-endpoint'
    app_db_username: 'crawler_readonly'
    ssmkey_rds_app_user_username_key: '/{{ project_id }}/{{ software_component }}/rds/readonly-username'
    ssmkey_rds_app_user_password_key: '/{{ project_id }}/{{ software_component }}/rds/readonly-password'
    sequence_privileges: 'SELECT'
    table_privileges: 'SELECT'
    function_privileges: 'EXECUTE'
```
