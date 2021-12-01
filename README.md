# AWS Wireguard terraform module

Bring up wireguard (WG) server and necessary lambda functions for managing wg users. To make user capable to use WG server you only need to add them in specified IAM group. Provide following abilities:
- Direct resource access in VPC subnets (private/public)
- Access AWS resources by internal names.
- Internet access, Wireguard server will perform NAT/packet forwarding
- You could add remove users to WG by adding or remove them from IAM group
- People how do setup can specify email address which will receive all WG clients configs 
- Can show WG client config by Invoke Lambda function

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

## Event flow diagram
When user will be added/removed from the IAM group, the following event flow will be processed.
![Event flow](event_flow.png)

## Examples 

### Common for all deployments
All kind of deployments will create Lambdas, EC2, Params in SSM, SNS topic, EventBridge rule. 

### Minimal example
Minimal example requires no arguments provided. Additionally it will create VPC, and necessary subnets. To retrieve client configurations, you could manually check SSM Params by AWS Web Console, or use bash command provided by TF output. 

After tf apply you need to add user to Wireguard group, wait 1 minute and then wg user can get his wg config file by calling api gateway or executing following script.
```
python3 ./scripts/apigateway-invoke.py ${module.api_gateway.apigatewayv2_api_api_endpoint }/wg-conf > wg-conf.conf
```
This command will put wg.conf file in current folder, just import it with wireguard client.

### existing-vpc
Deploy only default resources, all dependencies must be provided explicitly.

## Knowen issues
When you add user to WG group, the WG ec2 instance will be rebooted, the other users which already connected to the server will be interrupted. 

