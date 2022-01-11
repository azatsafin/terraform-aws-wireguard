import os
import boto3
import json
from botocore.exceptions import ClientError
import logging
aws_ssm = boto3.client('ssm')

wg_subnet = os.getenv('WG_SUBNET')
user_ssm_prefix = os.getenv('WG_SSM_USERS_PREFIX')
wg_config_ssm_path = os.getenv('WG_SSM_CONFIG_PATH')
wg_listen_port = os.getenv('WG_LISTEN_PORT')

def handler(event, context):
    # Getting caller identity
    try:
        username = event['requestContext']['authorizer']['jwt']['claims']['cognito:username']
    except Exception as e:
        print(e)
        return ("'can't get caller identity")
    # Getting user config by user name
    try:
        user_config = aws_ssm.get_parameter(Name=user_ssm_prefix + "/" + str(username), WithDecryption=True)
        return (json.loads(user_config['Parameter']['Value'])['ClientConf'])
    except ClientError as e:
        logging.error("Received error: %s", e, exc_info=True)
        # Only worry about a specific service error code
        if e.response['Error']['Code'] == 'ParameterNotFound':
            return ('User {0}: not exist/or not member of wireguard group'.format(user_arn))