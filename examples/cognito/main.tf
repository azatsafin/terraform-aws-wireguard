terraform {
  required_providers {
    aws = {
      version = "~>3.71.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

module "aws-wireguard" {
  source                = "../.."
  instance_type         = "t3.micro"
  listen-port           = "8080"
  aws_ec2_key           = "asafin"
  prefix                = "vpn"
  project-name          = "devtest"
  vpc_id                = "vpc-XXXXXXXXXXXXXXXXX"
  wireguard_subnet      = "subnet-XXXXXXXXXXXXXXXXXs"
  vpn_subnet            = "10.11.112.0/24"
  users_management_type = "cognito"
}

output "get_config_url" {
  value = module.aws-wireguard.get_conf_command
}