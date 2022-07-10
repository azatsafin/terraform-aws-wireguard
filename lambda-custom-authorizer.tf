 module "api-gateway-custom-authorizer" {
  count                          = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  source                         = "git::https://github.com/azatsafin/aws-github-custom-authorizer"
  resource_name_prefix           = local.name
  client_id                      = var.oauth2_client_id
  client_secret                  = var.oauth2_client_secret
  github_org                     = var.github_org_name
  authorized_lambda_function_arn = module.get_user_conf[0].lambda_function_arn
}