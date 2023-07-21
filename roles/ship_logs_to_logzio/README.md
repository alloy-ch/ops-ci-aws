# Ansible Role: `ship_logs_to_logzio`

This Ansible role:
*  creates a lambda function sends CloudWatch Logs to logz.io if it does not exist
*  creates a CloudWatch LogGroup if it does not exist
*  puts a subscription filter to send logs from the LogGroup to logz.io

## Parameters

| Param                                 | Mandatory | Type | Default                    | Description                                                                                                                                                                  |
|:--------------------------------------|:---------:|:----:|:---------------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `logzio_region`                       |    no     | str  | `eu`                       | Can be `''` or `'eu'`, so far all our sub accounts at logz.io are in `eu`. No reason to change it                                                                            |
| `logzio_format`                       |    No     | str  | `json`                     | Log message format, can be "json" or "text". If json, the lambda function will attempt to parse the message field as JSON and populate the event data with the parsed fields |
| `logzio_type`                         |    No     | str  | `logzio_cloudwatch_lambda` | Log message type. Valid value can be found at https://docs.logz.io/user-guide/log-shipping/built-in-log-types.html                                                           |
| `logzio_compress`                     |    No     | str  | `true`                     | Compress data before sending to logz.io, can be "true" or "false" (string)                                                                                                   |
| `default_log_group_retention_in_days` |    No     | int  | 3                          | The LogGroup will be created if the it does not exist. In this case, set the log retention to this value                                                                     |
| `ssmkey_logzio_token`                 |    Yes    | str  | -                          | Name of the SSM Parameter stores the logz.io token, must be of type `SecureString`                                                                                           |
| `logzio_log_group_to_monitor`         |    Yes    | str  | -                          | Name of the LogGroup to send logs to logz.io                                                                                                                                 |

## Outputs

None

## Examples

```ansible
- name: 'send lambda function logs to logz.io'
- include_role:
    name: 'ringier.aws_cicd.ship_logs_to_logzio'
  vars:
    ssmkey_logzio_token: '/alloy/devops/logzio-logs-shipping-token'
    logzio_log_group_to_monitor: '/aws/lambda/land-alloy-content-profiles-data-ingestion'
```
