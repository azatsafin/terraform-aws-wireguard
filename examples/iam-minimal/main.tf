terraform {
  required_providers {
    aws = {
      version = "~>3.71.0"
      source  = "hashicorp/aws"w
  }
}

provider "aws" {
  region = "eu-west-2"
}

module "aws-wireguard" {
  source                = "../.."
  instance_type         = "t3.micro"
  aws_ec2_key           = "asafin"
  prefix                = "vpn"
  project-name          = "vpn-demo"
  users_management_type = "iam"
}

output "get_config_url" {
  value = module.aws-wireguard.get_conf_command
}