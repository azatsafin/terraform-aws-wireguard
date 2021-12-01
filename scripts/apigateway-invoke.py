#!/usr/bin/env python3
"""
Provides a simple Python wrapper for invoking an API Gateway endpoint using IAM signed requests.

Example:
  python3 apigateway-invoke.py GET \
    https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/default/MethodName | jq .
"""

try:
    from urllib.parse import urlparse, urlencode, parse_qs
except ImportError:
    from urlparse import urlparse, parse_qs
    from urllib import urlencode

import re
import sys

import requests
from boto3 import Session
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest


def signing_headers(method, url_string):
    # Adapted from:
    #   https://github.com/jmenga/requests-aws-sign/blob/master/requests_aws_sign/requests_aws_sign.py
    region = re.search("execute-api.(.*).amazonaws.com", url_string).group(1)
    url = urlparse(url_string)
    path = url.path or '/'
    querystring = ''
    if url.query:
        querystring = '?' + urlencode(
            parse_qs(url.query, keep_blank_values=True), doseq=True)

    safe_url = url.scheme + '://' + url.netloc.split(
        ':')[0] + path + querystring
    request = AWSRequest(method=method.upper(), url=safe_url)
    SigV4Auth(Session().get_credentials(), "execute-api",
              region).add_auth(request)
    return dict(request.headers.items())


if __name__ == "__main__":
    url = sys.argv[1]
    r = requests.get(url, headers=signing_headers("get", url))
    print(r.content.decode("utf-8"))
