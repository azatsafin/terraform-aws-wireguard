module "webhook_2_sns" {
  count                          = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  source                         = "../github-webhook-handler"
  resource_name_prefix           = local.name
  github_secret                  = var.github_webhook_secret
}