resource "aws_iam_role" "get_user_conf" {
  count              = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  name               = "${local.name}-get-user-conf"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Sid       = ""
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "get_user_conf" {
  count  = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  name   = "${local.name}-get-user-conf"
  policy = <<POLICY
{
"Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "ssm:GetParameter"
            ],
            "Resource": [
              "arn:aws:ssm:${local.region}:${(local.account)}:parameter/${var.prefix}*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateNetworkInterface",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeInstances",
            "ec2:AttachNetworkInterface"
            ],
            "Resource": "*"
        },
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

resource "aws_iam_role_policy_attachment" "get_user_conf" {
  count      = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  policy_arn = aws_iam_policy.get_user_conf[0].arn
  role       = aws_iam_role.get_user_conf[0].name
}

module "get_user_conf" {
  count                 = var.users_management_type == "custom_api_authorizer" ? 1 : 0
  source                = "terraform-aws-modules/lambda/aws"
  version               = "3.2.1"
  create_package        = true
  create_role           = false
  create                = true
  create_layer          = false
  create_function       = true
  publish               = true
  function_name         = "${local.name}-get-user-conf"
  runtime               = "python3.9"
  handler               = "app.handler"
  memory_size           = 512
  timeout               = 30
  lambda_role           = aws_iam_role.get_user_conf[0].arn
  package_type          = "Zip"
  source_path           = "${path.module}/lambdas/get_user_conf_custom"
  environment_variables = {
    WG_SSM_USERS_PREFIX = local.wg_ssm_user_prefix
    WG_MANAGE_FUNCTION_NAME = "${local.name}-wg-manage"
  }
}
