import os
import boto3
import json
import logging

client_id = os.getenv('COGNITO_USER_POOL_CLIENT_ID')
cognito_pool_name = os.getenv('COGNITO_POOL_NAME')
cognito_region = os.getenv('COGNITO_REGION')

def handler(event, context):
    redirect_url = "https://" + cognito_pool_name + ".auth." + cognito_region + \
                        ".amazoncognito.com/login?client_id=" + client_id + \
                        "&response_type=token&scope=openid&redirect_uri=https://" + event['requestContext']['domainName'] + \
                        "/cognito-auth-redirect"
    print("Cognito auth uri is:{}".format(redirect_url))
    return {
        "statusCode": 301,
        "headers": {
            "Location": redirect_url
        }
    }
