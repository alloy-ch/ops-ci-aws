# Ansible Role: `create_acm_ssl_certificate`

This Ansible role creates a wildcard SSL certificate for the specific domain with AWS Certificate Manager if it does not exist.
It automatically handles the domain name ownership verification. 

## Parameters

| Param            | Mandatory | Type | Default | Description                                                   |
|:-----------------|:---------:|:----:|:--------|:--------------------------------------------------------------|
| `acm_region`     |    Yes    | str  | -       | The AWS region in which the SSL certificate should be created |
| `route53_region` |    Yes    | str  | -       | The AWS region in which the Route53 zone is located           |
| `base_domain`    |    Yes    | str  | -       | The domain name which requires the SSL certificate            |

NOTE:
*  concerning `acm_region` and `route53_region`, in general, we do not deal with multiple AWS regions. However, if an SSL certificate is
   to be used by CloudFront, it has to be created in `us-east-1`
*  concerning `base_domain`, FQDN name does not work here, because we create only wildcard certificate. If we specify www.newsglobe.io
   here, we create certificate *.www.newsglobe.io which is not desired.
*  **CAUTION**: this Ansible role handles domain-ownership verification using DNS approach. It waits for the verification endlessly.
   Therefore, to avoid running into a dead-end, it is very important to make sure that the specified domain has a Route53 zone opens to
   the public internet, and the very Route53 zone id is exactly the one as the output of PublicHostedZoneId at CloudFormation stack
   '{{ env }}-{{ project_id }}-route53'.

## Outputs

None

## Examples

```ansible
- name: 'create SSL certificate for the subdomain of each environment except at ops environment'
  include_role:
    name: 'create_acm_ssl_certificate'
  vars:
    base_domain: '{{ env }}.newsglobe.io'
    acm_region: 'us-east-1'
    route53_region: '{{ aws_region }}'
    when: env != 'ops'
```
