import os
import boto3
import json
import logging

project_name = os.getenv('LOCAL_NAME')
base_url = "wg-conf-cognito"

def client_html():
    html = """
        <!DOCTYPE html>
        <html>
        
        <head>
          <meta charset='utf-8'>
          <meta http-equiv='X-UA-Compatible' content='IE=edge'>
          <title>Page Title</title>
          <meta name='viewport' content='width=device-width, initial-scale=1'>
          <script>
            if (window.location.hash) {{
              let hash = window.location.hash.substring(1);
              const urlFragments = new URLSearchParams(hash);
              const id_token = urlFragments.get('id_token')
              console.log(id_token)
              if (id_token) {{
                console.log(urlFragments.get('id_token'))
                window.location.replace(`{0}?id_token=${{id_token}}`)
              }} else {{
                alert(`No "id_token" present in request`)
              }}
            }} else {{
              alert(`There is no fragment in request, most probably you didn't get TokenID`)
            }}
          </script>
        </head>
        
        <body>
        </body>
        
        </html>
        """.format(base_url)
    return html

def handler(event, context):
    print(event)
    print(context)
    return {
        "statusCode": 200,
        "body": client_html(),
        "headers": {
            'Content-Type': 'text/html',
        }
    }


