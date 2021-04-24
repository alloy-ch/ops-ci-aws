#!/usr/bin/python

from __future__ import absolute_import, division, print_function

__metaclass__ = type

import traceback

try:
    import boto3
    import botocore

    HAS_BOTO3 = True
except ImportError:
    HAS_BOTO3 = False

from ansible.module_utils._text import to_native
from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.ec2 import (get_aws_connection_info, ec2_argument_spec, boto3_conn, AWSRetry)


class CloudFormationServiceManager:
    """Handles CloudFormation Services"""

    def __init__(self, module):
        self.module = module

        try:
            region, ec2_url, aws_connect_kwargs = get_aws_connection_info(module, boto3=True)
            self.client = boto3_conn(module, conn_type='client', resource='cloudformation', region=region,
                                     endpoint=ec2_url, **aws_connect_kwargs)
            backoff_wrapper = AWSRetry.jittered_backoff(retries=10, delay=3, max_delay=30)
            self.client.describe_stacks = backoff_wrapper(self.client.describe_stacks)
        except botocore.exceptions.NoRegionError:
            self.module.fail_json(
                msg="Region must be specified as a parameter, in AWS_DEFAULT_REGION environment variable or in boto configuration file")
        except Exception as e:
            self.module.fail_json(msg="Can't establish connection - " + str(e), exception=traceback.format_exc())

    def describe_stacks(self, stack_name):
        try:
            kwargs = {'StackName': stack_name}
            response = self.client.describe_stacks(**kwargs).get('Stacks')
            if response is not None:
                return response
            self.module.fail_json(msg="Error describing stack - an empty response was returned")
        except Exception as e:
            if 'does not exist' in e.response['Error']['Message']:
                # missing stack, don't bail.
                return {}
            self.module.fail_json(msg="Error describing stack - " + to_native(e), exception=traceback.format_exc())


def to_dict(items, key, value):
    """ Transforms a list of items to a Key/Value dictionary """
    if items:
        return dict(zip([i.get(key) for i in items], [i.get(value) for i in items]))
    else:
        return dict()


def main():
    argument_spec = ec2_argument_spec()
    argument_spec.update(dict(stack_name=dict(type='str', required=True, description='Name of the CloudFormation stack'),))

    module = AnsibleModule(argument_spec=argument_spec, supports_check_mode=False)

    if not HAS_BOTO3:
        module.fail_json(msg='boto3 is required.')

    service_mgr = CloudFormationServiceManager(module)

    result = {'outputs': {}}

    for stack_description in service_mgr.describe_stacks(
        module.params.get('stack_name')):
        result['outputs'] = to_dict(stack_description.get('Outputs'), 'OutputKey', 'OutputValue')

    result['changed'] = False
    module.exit_json(**result)


if __name__ == '__main__':
    main()
