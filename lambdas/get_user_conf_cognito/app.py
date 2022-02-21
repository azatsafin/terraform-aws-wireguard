import os
import boto3
import json
from botocore.exceptions import ClientError
import logging
from botocore.config import Config

wg_subnet = os.getenv('WG_SUBNET')
user_ssm_prefix = os.getenv('WG_SSM_USERS_PREFIX')
wg_config_ssm_path = os.getenv('WG_SSM_CONFIG_PATH')
wg_listen_port = os.getenv('WG_LISTEN_PORT')
cognito_user_pool_id = os.getenv('COGNITO_USER_POOL_ID')
cognito_group = os.getenv('COGNITO_GROUP_NAME')
wg_manage_function_name = os.getenv('WG_MANAGE_FUNCTION_NAME')

boto3_conf = Config(read_timeout=5, retries={"total_max_attempts": 2})
aws_lambda = boto3.client('lambda', config=boto3_conf)
aws_ssm = boto3.client('ssm', config=boto3_conf)
aws_cognito = boto3.client('cognito-idp', config=boto3_conf)

def get_ssm_attrs(ssm_path):
    try:
        wg_ssm_config = aws_ssm.get_parameter(Name=ssm_path, WithDecryption=True)
    except Exception as e:
        print(e)
        return None
    if 'Parameter' in wg_ssm_config:
        return wg_ssm_config['Parameter']['Value'].split('\n')
    else:
        return None

def handler(event, context):
    # Getting caller identity
    try:
        username = event['requestContext']['authorizer']['jwt']['claims']['cognito:username']
    except Exception as e:
        print(e)
        return ("'can't get caller identity")
    # Check that config exist and user in VPN group, if so then call lambda function to create user wg config
    user_ssm_params = get_ssm_attrs(user_ssm_prefix + "/" + username)
    if user_ssm_params is None:
        try:
            user_groups = aws_cognito.admin_list_groups_for_user(Username=username,
                                                                 UserPoolId=cognito_user_pool_id, Limit=60)
        except Exception as e:
            print(e)
            return ("User: {} not present in Cognito User Pool".format(username))
        if (list(group['GroupName'] for group in user_groups['Groups'] if (cognito_group in group['GroupName']))):
            aws_lambda.invoke(FunctionName=wg_manage_function_name)
            user_ssm_params = get_ssm_attrs(user_ssm_prefix + "/" + username)
            return (json.loads(user_ssm_params[0])['ClientConf'])
        else:
            return "User {} not in group:{}".format(username, cognito_group)
    else:
        return (json.loads(user_ssm_params[0])['ClientConf'])
