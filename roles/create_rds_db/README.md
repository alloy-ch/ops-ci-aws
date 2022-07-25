# Ansible Role: `create_rds_db`

This Ansible role:
*  creates an AWS Aurora (PostgreSQL) cluster
*  creates a DB instance in the cluster
*  stores the credential of the super-admin user to SSM Parameter Store
*  creates a readonly user and stores its credential to SSM Parameter Store
*  registers the FQDN of both read/write and read-only endpoints as a CNAME at Route53

## Parameters

| Param                              | Mandatory | Type | Default                                                              | Description                                                                                                                                                                      |
|:-----------------------------------|:---------:|:----:|:---------------------------------------------------------------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `software_component`               |    Yes    | str  | -                                                                    | It contributes to many identifiers, e.g. the CloudFormation stacks named as {{ env }}-{{ project_id }}-{{ software_component }}-rds, will be rendered to `dev-scmi-crawler-rds.` |
| `base_domain`                      |    Yes    | str  | -                                                                    | The domain in which the FQDN of RDS endpoint should be registered to. This is a per-environment variable. e.g., for `dev`, it is `d.newsglobe.io`                                |
| `local_vpc_cidr`                   |    Yes    | str  | -                                                                    | The CIDR of the local VPC. It is used for the RDS security group, to make sure the services running in the VPC can access the RDS instance.                                      |
| `vpn_prefix_list_id_ipv4`          |    Yes    | str  | -                                                                    | The IP Prefix List Id of the VPN network(s). It is used for the RDS security group, to make sure the connections from the VPN server can access the RDS instance.                |
| `rds_route53_record_name`          |    No     | str  | `'{{ software_component }}-db.{{ base_domain }}'`                    | The FQDN of the read/write endpoint of AWS Aurora cluster.                                                                                                                       |
| `rds_route53_ro_record_name`       |    No     | str  | `'{{ software_component }}-db-ro.{{ base_domain }}'`                 | The FQDN of the readonly endpoint of AWS Aurora cluster.                                                                                                                         |
| `rds_db_name`                      |    No     | str  | `{{ project_id }}`                                                   | Database name at PostgreSQL. As we usually have one cluster hosts only one database, naming uniqueness does not bring additional benefit.                                        |
| `rds_schema_name`                  |    No     | str  | `{{ rds_db_name }}`                                                  | Schema name inside DB at PostgreSQL.                                                                                                                                             |
| `rds_port`                         |    No     | str  | `'5432'`                                                             | TCP port of PostgreSQL. Without special reason it should not be changed.                                                                                                         |
| `rds_instance_class`               |    No     | str  | `db.t4g.medium`                                                      | The [RDS instance class](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html) identifier.                                                       |
| `rds_instances_amount`             |    No     | int  | 1                                                                    | Number of RDS instances to add into the Aurora cluster.                                                                                                                          |
| `ssmkey_rds_master_username_key`   |    No     | str  | `'/{{ project_id }}/{{ software_component }}/rds/master-username'`   | Name of the SSM Parameter to store RDS master username. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                       |
| `ssmkey_rds_master_password_key`   |    No     | str  | `'/{{ project_id }}/{{ software_component }}/rds/master-password'`   | Name of the SSM Parameter to store RDS master password. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                       |
| `readonly_user_name`               |    No     | str  | `'{{ software_component }}_readonly'`                                | Username of the RDS readonly user.                                                                                                                                               |
| `ssmkey_rds_readonly_username_key` |    No     | str  | `'/{{ project_id }}/{{ software_component }}/rds/readonly-username'` | Name of the SSM Parameter to store RDS readonly username. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                     |
| `ssmkey_rds_readonly_password_key` |    No     | str  | `'/{{ project_id }}/{{ software_component }}/rds/readonly-password'` | Name of the SSM Parameter to store RDS readonly password. If the SSM Parameter does not exist, this role will create it and set it to the appropriate value.                     |
|                                    |           |      |                                                                      |                                                                                                                                                                                  |

## Outputs

None

## Examples

```ansible
- include_role:
    name: 'ringier.aws_cicd.create_rds_db'
  vars:
    base_domain: 'p.newsglobe.io'
    vpn_prefix_list_id_ipv4: 'pl-0638be83d413cf7ad'
    rds_instance_class: 'db.t3.medium'
```
