# Ansible Role: `run_psql`

This executes a list of provided SQL queries on the specified Postgres database. It supports both username + password and RDS IAM Authentication.

This commad will always use full server certificate verification - meaning you cannot use a custom domain for `rds_endpoint`.

|   Param            |   Mandatory  |   Type  |   Default                             |   Description                                                                            |
|--------------------|--------------|---------|---------------------------------------|------------------------------------------------------------------------------------------|
|   `rds_endpoint`   |   Yes        |   str   |   -                                   |   The hostname/endpoint of the Postgres server                                           |
|   `rds_port`       |   No         |   Int   |   5432                                |   The port of the Postgres server                                                        |
|   `rds_username`   |   Yes        |   str   |   -                                   |   The username to user                                                                   |
|   `rds_password`   |   No         |   str   |   -                                   |   The password of the user. If not provided: RDS IAM Authentication will be used         |
|   `rds_db_name`    |   Yes        |   str   |   -                                   |   The database                                                                           |
|   `ssmkey_rds_ca`  |   No         |   str   |  `/{{ env }}/{{ project_id }}/rds-ca` |   The SSM key containing the certificate of the CA for the database server certificate   |
|   `queries`        |   Yes        |   List  |   -                                   |   The queries to be executed. Schema: `{ name: str, query: str }`                        |

## Outputs

None

## Examples

```ansible
- include_role:
    name: 'run_psql'
  vars:
    rds_endpoint: '{{ rds_endpoint }}'
    rds_username: '{{ rds_username }}'
    rds_db_name: '{{ rds_db_name }}'
    # Note: since rds_password is not provided RDS IAM Authentication will be used
    queries:
    - name: Drop public schema
      query: "DROP SCHEMA IF EXISTS public"
    - name: Create schema {{helios_postgres_schema}}
      query: "CREATE SCHEMA IF NOT EXISTS {{helios_postgres_schema}} AUTHORIZATION {{rds_username}}"
    - name: Create pgcrypto extension
      query: "CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA {{helios_postgres_schema}};"
    - name: Create pgcrypto extension
      query: "CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA {{helios_postgres_schema}};"
    - name: Create role sso_helios_role_readonly
      query: >-
        DO
        $do$
        BEGIN
          IF EXISTS (
              SELECT FROM pg_catalog.pg_roles
              WHERE  rolname = 'sso_helios_role_readonly') THEN

              RAISE NOTICE 'Role "sso_helios_role_readonly" already exists. Skipping.';
          ELSE
              BEGIN   -- nested block
                CREATE ROLE sso_helios_role_readonly WITH inherit;

                GRANT connect,temp ON DATABASE {{rds_db_name}} TO sso_helios_role_readonly;
                GRANT usage ON SCHEMA {{helios_postgres_schema}} TO sso_helios_role_readonly;
                GRANT select ON ALL TABLES IN SCHEMA {{helios_postgres_schema}} TO sso_helios_role_readonly;

                ALTER DEFAULT PRIVILEGES IN SCHEMA {{helios_postgres_schema}} GRANT select ON TABLES TO sso_helios_role_readonly;
              EXCEPTION
                WHEN duplicate_object THEN
                    RAISE NOTICE 'Role "sso_helios_role_readonly" was just created by a concurrent transaction. Skipping.';
              END;
          END IF;
        END
        $do$;
```
