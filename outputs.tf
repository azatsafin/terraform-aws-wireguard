output "get_conf_command" {
  description = "Getting configuration for specific user"
  value       = <<-EOT
  aws --region=${local.region} lambda invoke --function-name ${module.create_user_conf.lambda_function_name} \
--payload '{ "user": "you_aws_username" }' --cli-binary-format raw-in-base64-out lambda-out.txt \
&& cat lambda-out.txt | jq -r  > wg.conf && rm lambda-out.txt
EOT
}

output "get_conf_url" {
  description = "If you are using Cognito, endusers can obtain their wireguard configuration by open this url"
  value = var.users_management_type == 'cognito' ? "${module.api_gateway_cognito[0].apigatewayv2_api_api_endpoint}/config" : null
}