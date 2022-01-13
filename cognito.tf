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
  clients        = [
    {
      allowed_oauth_flows                  = ["implicit", "code"]
      allowed_oauth_flows_user_pool_client = true
      allowed_oauth_scopes                 = ["openid"]
      callback_urls                        = [
        "${module.api_gateway_cognito[0].apigatewayv2_api_api_endpoint}/cognito-auth-redirect"
      ]
      default_redirect_uri                 = "${module.api_gateway_cognito[0].apigatewayv2_api_api_endpoint}/cognito-auth-redirect"
      explicit_auth_flows                  = []
      generate_secret                      = true
      logout_urls                          = []
      name                                 = "${local.name}-wg-cognito-app-client"
      read_attributes                      = ["email"]
      supported_identity_providers         = ["COGNITO"]
      write_attributes                     = []
      access_token_validity                = 1
      id_token_validity                    = 1
      refresh_token_validity               = 60
      token_validity_units                 = {
        access_token  = "hours"
        id_token      = "hours"
        refresh_token = "days"
      }
    }
  ]
  user_groups    = [
    {
      name        = var.cognito_user_group
      description = "${var.cognito_user_group} group members will be able to use Wireguard VPN service"
    }
  ]
}

resource "aws_cognito_user_pool_client" "wg-vpn" {
  count                                = var.cognito_user_pool_id !=0 && var.users_management_type == "cognito" ? 1 : 0
  name                                 = "VPN authorizer"
  generate_secret                      = true
  user_pool_id                         = var.cognito_user_pool_id
  callback_urls                        = [
    "${module.api_gateway_cognito[0].apigatewayv2_api_api_endpoint}/cognito-auth-redirect"
  ]
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid"]
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows_user_pool_client = true
  explicit_auth_flows                  = []
}