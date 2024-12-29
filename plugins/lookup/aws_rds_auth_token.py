# python 3 headers, required if submitting to Ansible
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
  name: file
  author: Erik Jonsson Thorén / Ringier AG (erik.jonsson@ringier.ch)
  version_added: "2.5.0"  # for collections, use the collection version, not the Ansible version
  short_description: Generates AWS RDS IAM Auth Token
  description:
      - Generates AWS RDS IAM Auth Token
  options:
    hostname:
      type: string
      required: True
    username:
      type: string
      required: True
    port:
      type: int
      required: False
      default: 5432
'''

# The overall structure of this plugin is based on https://github.com/ansible-collections/amazon.aws/blob/9.1.0/plugins/lookup/aws_account_attribute.py

try:
    import botocore
except ImportError:
    pass  # Handled by AWSLookupBase

from ansible_collections.amazon.aws.plugins.module_utils.retries import AWSRetry
from ansible_collections.amazon.aws.plugins.plugin_utils.lookup import AWSLookupBase

class LookupModule(AWSLookupBase):
    def run(self, terms, variables, **kwargs):
        super().run(terms, variables, **kwargs)

        client = self.client("rds", AWSRetry.jittered_backoff())

        HOSTNAME = self.get_option("hostname")
        PORT = self.get_option("port", 5432)
        USERNAME = self.get_option("username")

        token = client.generate_db_auth_token(DBHostname=HOSTNAME, Port=PORT, DBUsername=USERNAME)

        return [token]
