# Ansible Role: `create_acm_ssl_certificate`

This Ansible role creates a certificate for the specific domain with AWS Certificate Manager if it does not exist, the domain name can be
FQDN or wildcard domain.

This role automatically handles the domain name ownership verification (via DNS validation method) if (and only if) both of the following
are true:
*  The certificate domain is hosted in Amazon Route 53
*  The domain resides in your AWS account


## Parameters

| Param             | Mandatory | Type | Default                                                                   | Description                                                   |
|:------------------|:---------:|:----:|:--------------------------------------------------------------------------|:--------------------------------------------------------------|
| `acm_region`      |    No     | str  | `{{ aws_region }}`                                                        | The AWS region in which the SSL certificate should be created |
| `route53_region`  |    No     | str  | `{{ aws_region }}`                                                        | The AWS region in which the Route53 zone is located           |
| `domain_name`     |    No     | str  | `{{ base_domain }}`                                                       | The domain name which requires the SSL certificate            |
| `is_wildcard`     |    No     | bool | `True`                                                                    | If true, create a wildcard certificate                        |
| `route53_zone_id` |    No     | str  | Output `PublicHostedZoneId` of stack `{{ env }}-{{ project_id }}-route53` |                                                               |

NOTE:
*  concerning `acm_region` and `route53_region`, in general we do not deal with multiple AWS regions. However, if an SSL certificate is
   to be used by CloudFront, it has to be created in `us-east-1`
*  concerning `domain_name`, it defines the domain name a certificate is created for. The eventual value is influenced by parameter
   `is_wildcard`. If `is_wildcard` is not defined or has a truthy value, this role appends a wildcard prefix to `domain_name`. e.g.:
   *  `domain_name: 'rcplus.io'` without `is_wildcard` results in a wildcard certificate for domain `*.rcplus.io`
   *  `domain_name: 'www.rcplus.io'` and `is_wildcard: False` yields to a single-domain certificate for `www.rcplus.io`
*  **CAUTION**: this Ansible role handles domain-ownership verification using DNS method. It waits for the verification endlessly, well,
   until Ansible play timeout. Therefore, to avoid running into a dead-end, it is very important to make sure that the specified domain
   has a Route53 zone opens to the public internet, and the current user/role has the permission to create/delete entries in the zone.

## Outputs

None

## Examples

```ansible
- name: 'create wildcard SSL certificate for the subdomain of each environment except at ops environment'
  include_role:
    name: 'create_acm_ssl_certificate'
  vars:
    domain_name: '{{ env }}.rcplus.io'
    acm_region: 'us-east-1'
    when: env != 'ops'
```
