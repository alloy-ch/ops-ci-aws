# Ansible Role: `create_db_user_iam_auth`

This Ansible role:
*  creates a user at the PostgreSQL database, with the permissions defined in the parameters (if not provided only grants database connect priviliege)
*  stores the username at SSM ParameterStore as a String
*  does not set a password, instead grants the `rds_iam` role enabling IAM authentication

**NOTE:** If the user exists, the Ansile Role does not change anything.
**NOTE:** This commad will always use full server certificate verification - meaning you cannot use a custom domain for `rds_endpoint`.

## Parameters

|   Param                                      |   Mandatory    |   Type  |   Default                                                             |   Description                                                                                                                                                                                              |
|----------------------------------------------|----------------|---------|-----------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|   `user_username`                            |   Yes          |   str   |   -                                                                   |   Name of the PostgreSQL role to be created. e.g. `scmi_change_monitor_user`                                                                                                                               |
|   `ssmkey_user_username`                     |   Yes          |   str   |   -                                                                   |   Key of the SSM Parameter to store the username. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                                                       |
|   `privileges`                               |   No           |   str   |   `connect_only`                                                      |   Privileges to be granted to the new user on database in the schema `rds_schema_name`. Choices: `connect_only` \| `read` \| `read_write`. Will also create default privileges for any new objects.         |
|   `env`                                      |   Yes          |   str   |   -                                                                   |                                                                                                                                                                                                            |
|   `project_id`                               |   Yes          |   str   |   -                                                                   |                                                                                                                                                                                                            |
|   `software_component`                       |   Yes          |   str   |   -                                                                   |   Used to lookup `/{{ project_id }}/{{ software_component }}/rds/master-username`                                                                                                                          |
|   `ssmkey_rds_master_username_key`           |   No           |   str   |   `'/{{ project_id }}/{{ software_component }}/rds/master-username'`  |   Name of the SSM Parameter to store RDS master username.                                                                                                                                                  |
|   `rds_password`                             |   No           |   str   |   If not provided RDS IAM authentication will be used                 |   The master user password. If not provided RDS IAM authentication will be used.                                                                                                                           |
|   `rds_endpoint_cloudformation_export_name`  |   Conditional  |   str   |   -                                                                   |   Mutually exclusive with `rds_endpoint`. Specify the CloudFormation stack export name of the RDS endpoint. e.g. `scmi-{{ software_component }}-rds-endpoint`                                              |
|   `rds_endpoint`                             |   Conditional  |   str   |   -                                                                   |   Mutually exclusive with `rds_endpoint_cloudformation_export_name`. Specify the RDS endpoint (without protocol and port) e.g. `dev-scmi-crawler-aurora.cluster-c2qxetkc4ajc.eu-west-1.rds.amazonaws.com`  |
|   `rds_db_name`                              |   No           |   str   |   `{{ project_id }}`                                                  |   Database name at PostgreSQL. As we usually have one cluster hosts only one database, naming uniqueness does not bring additional benefit.                                                                |
|   `rds_schema_name`                          |   No           |   str   |   `{{ rds_db_name }}`                                                 |   Schema name inside DB at PostgreSQL.                                                                                                                                                                     |
|   `rds_port`                                 |   No           |   str   |   `'5432'`                                                            |   TCP port of PostgreSQL. Without special reason it should not be changed.                                                                                                                                 |
|   `ssmkey_rds_ca`                            |   No           |   str   |  `/{{ env }}/{{ project_id }}/rds-ca`                                 |   The SSM key containing the certificate of the CA for the database server certificate                                                                                                                     |

## Outputs

None

## Examples

```ansible
- include_role:
    name: 'ringier.aws_cicd.create_db_user_iam_auth'
  vars:
    user_username: 'app-user'
    ssmkey_user_username: '{{ user_ssmkey }}'
    privileges: 'read_write'
    rds_endpoint: "{{ storage_stack.outputs.RdsInstanceEndpointAddress }}"
    rds_port: "{{ storage_stack.outputs.RdsInstanceEndpointPort }}"
```
