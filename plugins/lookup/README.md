# Ansible modules

## `aws_rds_auth_token`

This Ansible lookup retrieves RDS IAM authentication token

### Example

```ansible
  - set_fact:
      rds_password: "{{ lookup('aws_rds_auth_token', hostname=rds_endpoint, port=rds_port, username=rds_username )}}"
```
