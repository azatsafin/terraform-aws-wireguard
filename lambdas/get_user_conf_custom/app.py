import os
import boto3
import json
from botocore.exceptions import ClientError
import logging
from botocore.config import Config

user_ssm_prefix = os.getenv('WG_SSM_USERS_PREFIX')

boto3_conf = Config(read_timeout=30, retries={"total_max_attempts": 1})
aws_lambda = boto3.client('lambda', config=boto3_conf)
aws_ssm = boto3.client('ssm', config=boto3_conf)
wg_manage_function_name = os.getenv('WG_MANAGE_FUNCTION_NAME')


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
        username = event['requestContext']['authorizer']['lambda']['login']
    except Exception as e:
        print(e.__str__())
        return ("can't get caller identity, error: {}".format(str(e)))
    # Check that config exist and user in VPN group, if so then call lambda function to create user wg config
    user_ssm_params = get_ssm_attrs(user_ssm_prefix + "/" + username)
    print(json.dumps(event['requestContext']['authorizer']['lambda']))
    if user_ssm_params is not None:
        return (json.loads(user_ssm_params[0])['ClientConf'])
    else:
        try:
            response = aws_lambda.invoke(FunctionName=wg_manage_function_name, InvocationType="RequestResponse",
                                         Payload=json.dumps({"action": "member_added", "source": "github",
                                                             "user": event['requestContext']['authorizer']['lambda']}))
        except Exception as e:
            print(e.__str__())
            return {"Error": "wg-manage invocation take to much time"}

        if response['StatusCode'] == 200:
            user_ssm_params = get_ssm_attrs(user_ssm_prefix + "/" + username)
            if user_ssm_params is not None:
                return (json.loads(user_ssm_params[0])['ClientConf'])
        else:
            return {"Error": "Something went wrong, user config could not be created"}
