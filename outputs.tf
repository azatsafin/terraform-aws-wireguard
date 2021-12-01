output "get_conf_command" {
  description = <<-EOT
  Getting configuration for specific user, the user determined by user creds,
  so we are expecting aws user access key and secret key or aws profile exposed as env variables
EOT
  value       = <<-EOT
python3 ./scripts/apigateway-invoke.py ${module.api_gateway.apigatewayv2_api_api_endpoint }/wg-conf > wg-conf.conf
EOT
}
