terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      version = "~> 4.9.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

module "aws-wireguard" {
  source                = "../.."
  instance_type         = "t3.micro"
  aws_ec2_key           = "asafin"
  prefix                = "github"
  project-name          = "vpn-demo"
  users_management_type = "custom_api_authorizer"
  github_org_name       = "provectus"
  oauth2_client_id      = var.client_id
  oauth2_client_secret  = var.client_secret
}

output "get_config_url" {
  value = module.aws-wireguard.get_conf_command
}

variable "client_id" {}

variable "client_secret" {}