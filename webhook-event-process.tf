resource "aws_iam_policy" "webhook_event_process" {
  count  = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  name   = "${local.name}-webhook-event-process"
  policy = <<POLICY
{
"Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": "${module.wg_manage.lambda_function_arn}"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "webhook_event_process" {
  count      = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  policy_arn = aws_iam_policy.webhook_event_process[0].arn
  role       = module.webhook_processing[0].lambda_role_name
}

module "webhook_processing" {
  count                 = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  source                = "terraform-aws-modules/lambda/aws"
  version               = "3.2.1"
  create_package        = true
  create_role           = true
  create                = true
  create_layer          = false
  create_function       = true
  publish               = true
  function_name         = "${local.name}-github-webhook-processing"
  runtime               = "python3.9"
  handler               = "app.handler"
  memory_size           = 512
  timeout               = 30
  package_type          = "Zip"
  source_path           = "${path.module}/lambdas/github-webhook-processing"
  environment_variables = {
    SNS_TOPIC_ARN                      = module.webhook_2_sns[0].sns_topic_arn
    WG_MANAGE_LAMBDA                   = module.wg_manage.lambda_function_name
    GITHUB_ORGANIZATION_PROCESS_EVENTS = "[\"deleted\", \"member_removed\", \"renamed\"]"
    #Could be expanded with member_added
    #In that case wireguard user config will be created when user added
    #https://docs.github.com/en/developers/webhooks-and-events/webhooks/webhook-events-and-payloads#organization
  }
}

resource "aws_sns_topic_subscription" "webhook_processing" {
  count     = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  topic_arn = module.webhook_2_sns[0].sns_topic_arn
  protocol  = "lambda"
  endpoint  = module.webhook_processing[0].lambda_function_arn
  filter_policy = jsonencode(tomap({"github_event": ["organization"]}))
}

resource "aws_lambda_permission" "webhook_processing_from_sns" {
  count     = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = module.webhook_processing[0].lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = module.webhook_2_sns[0].sns_topic_arn
}