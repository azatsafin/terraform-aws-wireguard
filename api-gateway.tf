module "api_gateway_iam" {
  count  = var.users_management_type == "iam" ? 1 : 0
  source = "terraform-aws-modules/apigateway-v2/aws"

  name                   = "${local.name}-get-conf"
  description            = "API for getting wg config"
  protocol_type          = "HTTP"
  create_api_domain_name = false
  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 100
    throttling_rate_limit    = 100
  }

  integrations = {
    "GET /wg-conf-iam" = {
      lambda_arn             = module.create_user_conf.lambda_function_arn
      payload_format_version = "2.0"
      authorization_type     = "AWS_IAM"
    }
  }
}

module "api_gateway_cognito" {
  count                  = var.users_management_type == "cognito" ? 1 : 0
  source                 = "terraform-aws-modules/apigateway-v2/aws"
  name                   = "${local.name}-get-conf"
  description            = "API for getting wg config"
  protocol_type          = "HTTP"
  create_api_domain_name = false
  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 100
    throttling_rate_limit    = 100
  }

  integrations = {
    "GET /wg-conf-cognito"       = {
      lambda_arn             = module.create_user_conf.lambda_function_arn
      payload_format_version = "2.0"
      authorization_type     = "JWT"
      integration_type       = "AWS_PROXY"
      authorizer_id          = aws_apigatewayv2_authorizer.cognito[0].id
    }
    "GET /cognito-auth-redirect" = {
      lambda_arn             = module.cognito_auth_redirect[0].lambda_function_arn
      payload_format_version = "2.0"
      integration_type       = "AWS_PROXY"
    }
    "GET /config" = {
      lambda_arn             = module.redirect_2cognito[0].lambda_function_arn
      payload_format_version = "2.0"
      integration_type       = "AWS_PROXY"
    }
  }
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  count            = var.users_management_type == "cognito" ? 1 : 0
  api_id           = module.api_gateway_cognito[0].apigatewayv2_api_id
  authorizer_type  = "JWT"
  identity_sources = ["$request.querystring.id_token"]
  name             = "${local.name}-wg-cognito"

  jwt_configuration {
    audience = [var.cognito_user_pool_id != null ? var.cognito_user_pool_id : module.wg_cognito_user_pool.client_ids[0]]
    issuer   = "https://${module.wg_cognito_user_pool.endpoint}"
  }
}

resource "aws_lambda_permission" "create_user_conf" {
  statement_id  = "AllowAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${local.name}-create-user-conf"
  principal     = "apigateway.amazonaws.com"
  source_arn    = var.users_management_type == "iam" ? "${module.api_gateway_iam[0].apigatewayv2_api_execution_arn}/*/*/*" : "${module.api_gateway_cognito[0].apigatewayv2_api_execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "cognito-auth-redirect" {
  count         = var.users_management_type == "cognito" ? 1 : 0
  statement_id  = "AllowAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${local.name}-cognito-auth-redirect"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway_cognito[0].apigatewayv2_api_execution_arn}/*/*/*"
}

resource "aws_lambda_permission" "redirect_2cognito" {
  count         = var.users_management_type == "cognito" ? 1 : 0
  statement_id  = "AllowAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${local.name}-redirect-2cognito"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${module.api_gateway_cognito[0].apigatewayv2_api_execution_arn}/*/*/*"
}