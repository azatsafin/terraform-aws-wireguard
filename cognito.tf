module "wg_cognito_user_pool" {
  source         = "lgallard/cognito-user-pool/aws"
  user_pool_name = "${local.name}-wg-user-pool"
  enabled        = var.cognito_user_pool_id == null && var.users_management_type == "cognito" ? true : false
  tags           = {
    Owner       = "infra"
    Environment = "production"
    Terraform   = true
  }
  domain         = "${local.name}-wg-user-pool"
  user_groups    = [
    {
      name        = var.cognito_user_group
      description = "${var.cognito_user_group} group members will be able to use Wireguard VPN service"
    }
  ]
}

resource "aws_cognito_user_pool_client" "wg-vpn" {
  count                                = var.users_management_type == "cognito" ? 1 : 0
  name                                 = "VPN authorizer"
  generate_secret                      = true
  user_pool_id                         = var.cognito_user_pool_id != null ? var.cognito_user_pool_id : module.wg_cognito_user_pool.id
  callback_urls                        = [
    var.cognito_call_back_app_url != null ? "https://${var.cognito_call_back_app_url}/cognito-auth-redirect" : "${module.api_gateway_cognito[0].apigatewayv2_api_api_endpoint}/cognito-auth-redirect"
  ]
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  explicit_auth_flows                  = []
}