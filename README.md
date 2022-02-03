# AWS Wireguard terraform module
This module bringing up Wireguard server on EC2 instance and setup necessary Lambda function which automate
managing of users.
Currently, module support two types of user management:
1. Based presence of IAM group
2. Based presence of Cognito user pool

Common specifications:
- Direct resource access in VPC subnets (private/public), all resources in the same VPC with VPN server could be reachable.
- Access AWS resources by internal names.
- Internet access, Wireguard server will perform NAT/packet forwarding 
- You can limit subnets to which user will get access, usable when you need to provide VPN access to specific resource instead of routing all traffic via VPN server
- Admin can setup email address which will receive all WG clients configs when user added
- User client configurations and wg server config stored in AWS SSM param
- EC2 VPN instance has special service to reload WG config when users added/removed

Cognito management type details (currently supported):
- You could add remove users to WG by managing it in Cognito group, user should be active member of Cognito user pool
- Module can create new Cognito user pool, or you can use existing cognito pool. If you use existing pool, new app client will be created in existing pool.
- Users can get their config by calling URL provided with 'get_conf_url' module output. When user call URL, it will get redirect to Cognito UI for authentication, after successful authentication it will be redirected to API Gateway and mapped Lambda function. Lambda function will generate user config if it not yet exist, and update WG configuration and display Wireguard  client configuration in browser. 

IAM management type details (old method, inconvenient for users):
- You could add remove users to WG by adding or remove them from IAM group
- Users can receive WG config by calling Lambda function through API Gateway by AWS CLI, user credentials must be provided

## Inputs
| Name  | Description | Type  | Default  | Required  |
|---|---|---|---|---|
| instance_type  |  Instance type which will be used by Wireguard VPN server. Please note - it should have enhanced network support | string  | t3.small   | no  |
| wg_group_name  |  AWS IAM group name, members of that group will be members of wireguard server. If group not exist, it will be created automatically. | string  | wireguard  | no  |
| aws_ec2_key  | EC2 key name. If provided, ec2 Security group will allow external access by 22 tcp port (ssh)  | string  | null  | no  |
| project-name  | The name of the project for which VPN server will be deployed, not related to any feature. Just used to construct name/path for AWS resources  | string   | vpn-service  | no  |
| prefix  | The prefix name of the project for which VPN server will be deployed, not related to any feature. Just used to construct name/path for AWS resources  /${prefix}/{project-name}/resource| string   | wireguard  | no  |
| vpc_cidr  | The CIDR block for the VPC. It must be provided if you wish to create Wireguard in new VPC with specific CIDR.  | string  | 10.11.0.0/16  | no  |
| vpc_id  | VPC ID, must be provided if you want to deploy Wireguard server in existing VPC. If this value not provided, the module will create new VPC  | string  | null  | no  |
| wireguard_subnet  | Subnet ID where wireguard server and management lambdas will be deployed. Must be provided if you wish to deploy WG to your VPC.  | string  | "10.11.0.0/16"  | no  |
| vpn_subnet  | VPN subnet, VPN clients will get internal IPs from this subnet  | string  | "10.111.111.0/24"  | no  |
| wg_admin_email  | If specified, this email will receive  wireguard configurations for all clients. Configurations will be send by AWS SES. Please make sure that SES out of sandbox or admin email verified.  | string  | null  | no  |
| cognito_user_pool_id | If you already have existing Cognito user pool, please provide it id, otherwise new pool will be created | string | null | no |
|cognito_user_group| Only members on this group will have vpn access, default members will not be able to receive config/use vpn | string | vpn | no |
| cognito_call_back_app_url | You can set your own domain name for call back url, should be used when you want to use your own domain name instead of API Gateway execution URL | string | null | no |
| users_management_type | This module support two user managment source, IAM and Cognito. IAM is more usable for the infrastructure teams, where all members already have IAM user. Cognito is more usable for the teams who would like to manage VPN outside of IAM, and it more user friendly | string | iam | no |

## Examples 

### Cognito
Deploy module in existing VPN and Subnet. User management type set to cognito. Module will create ec2 instance with installed services: Wireguard and config updater. Cognito user pool, Cognito app client and necessary lambda functions. 

### Minimal example
Minimal example requires no arguments provided, it will create VPC, necessary subnets and all necessary lambda functions. To retrieve client configurations, you could manually check SSM Params by AWS Web Console, or use bash command provided by TF output. 

After tf apply you need to add user to Wireguard group, wait 1 minute and then wg user can get his wg config file by calling api gateway or executing following script.
```
python3 ./scripts/apigateway-invoke.py ${module.api_gateway.apigatewayv2_api_api_endpoint }/wg-conf > wg-conf.conf
```
This command will put wg.conf file in current folder, just import it with wireguard client.

### existing-vpc
Deploy only default resources, all dependencies must be provided explicitly.

### Enjoy, please feel free to create Issues if you face some bugs or obstacles. 