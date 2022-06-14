output "get_conf_command" {
  description = "Getting configuration for specific user"
  value       = var.users_management_type == "iam" || var.users_management_type == "cognito" ? (
          var.users_management_type == "iam" ? (
          "python3 ./scripts/apigateway-invoke.py ${module.api_gateway_iam[0].apigatewayv2_api_api_endpoint}/wg-conf-iam > wg-conf.conf") : (
    "open ${module.api_gateway_cognito[0].apigatewayv2_api_api_endpoint}/config")) : "open ${module.api-gateway-custom-authorizer[0].oauth2_login}"
}