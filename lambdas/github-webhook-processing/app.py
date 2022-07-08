###Getting messages from SNS and trigger wg-manage lambda function with necessary payload
import os
import boto3
import json
import logging

sns_topic_arn = os.getenv('SNS_TOPIC_ARN')
wg_manage_lambda = os.getenv('WG_MANAGE_LAMBDA')
github_organization_process_events = json.loads(os.getenv('GITHUB_ORGANIZATION_PROCESS_EVENTS'))
aws_lambda = boto3.client('lambda')

def handler(event, context):
    print(event)
    message = event['Records'][0]['Sns']['Message']
    message = json.loads(message)
    print(message)
    if message['action'] in github_organization_process_events:
        payload = {"action": message['action'], "user": {"login": message['membership']['user']['login']}}
        aws_lambda.invoke(FunctionName=wg_manage_lambda, Payload=bytes(json.dumps(payload), encoding='utf8'))

    return None
