import os
import boto3
import json
from botocore.exceptions import ClientError
import logging

aws_ssm = boto3.client('ssm')
aws_lambda = boto3.client('lambda')
aws_iam = boto3.client('iam')

wg_subnet = os.getenv('WG_SUBNET')
user_ssm_prefix = os.getenv('WG_SSM_USERS_PREFIX')
wg_config_ssm_path = os.getenv('WG_SSM_CONFIG_PATH')
wg_listen_port = os.getenv('WG_LISTEN_PORT')
iam_group = os.getenv('IAM_WG_GROUP_NAME')
wg_manage_function_name = os.getenv('WG_MANAGE_FUNCTION_NAME')



def get_iam_group_membership():
    def get_next_item(marker):
        if not marker:
            request_params = {
                "GroupName": iam_group
            }
        else:
            request_params = {
                "GroupName": iam_group,
                "Marker": marker
            }
        iam_users = []
        try:
            iam_users_resp = aws_iam.get_group(**request_params)
        except Exception as e:
            print(e)
            return None
        for user in iam_users_resp['Users']:
            iam_users.append(user['UserName'])
        if 'Marker' in iam_users_resp:
            iam_users += get_next_item(iam_users_resp['Marker'])
        return iam_users

    return get_next_item(None)


def handler(event, context):
    # Getting caller identity
    try:
        user_arn = event['requestContext']['authorizer']['iam']['userArn']
    except Exception as e:
        print(e)
        return "can't get caller identity"
    # Getting user config by user name
    user_name = user_arn.split(":")[-1].split("/")[-1]
    list_of_members = get_iam_group_membership()
    print(user_name)
    print(list_of_members)
    # Check that user belong to VPN group
    if user_name in list_of_members:
        # Re-create user conf if it not exists
        aws_lambda.invoke(FunctionName=wg_manage_function_name)
        # Try to read user conf from SSM
        try:
            user_ssm_params = aws_ssm.get_parameter(Name=user_ssm_prefix + "/" + user_name, WithDecryption=True)
            return json.loads(user_ssm_params['Parameter']['Value'])['ClientConf']
        except ClientError as e:
            logging.error("Received error: %s", e, exc_info=True)
            return 'Error in getting user conf, please see lambda logs for details'
    else:
        return 'User {0}: not exist/or not member of wireguard group'.format(user_arn)
