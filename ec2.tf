resource "aws_iam_instance_profile" "ec2_vpn_server" {
  name_prefix = local.name
  role        = aws_iam_role.ec2_vpn_server.name
}

data "aws_iam_policy_document" "ec2_vpn_server" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_vpn_server" {
  name_prefix           = "${local.name}-"
  force_detach_policies = true
  assume_role_policy    = data.aws_iam_policy_document.ec2_vpn_server.json
}

resource "aws_iam_policy" "ec2_vpn_server_ssm" {
  policy = <<POLICY
{
"Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "ssm:DescribeParameters",
              "ssm:GetParameter"
            ],
            "Resource": [
              "arn:aws:ssm:${local.region}:${(local.account)}:parameter/${var.prefix}*"
            ]
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

resource "aws_iam_role_policy_attachment" "ec2_vpn_server_ssm" {
  policy_arn = aws_iam_policy.ec2_vpn_server_ssm.arn
  role       = aws_iam_role.ec2_vpn_server.name
}


data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu-minimal/images/hvm-ssd/ubuntu-focal-20.04-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "ec2_vpn_server" {
  name        = "${local.name}-ec2_vpn_server"
  description = "allow external access"
  vpc_id      = local.wg_vpc_id
  ingress     = [
    {
      description      = "VPN traffic"
      from_port        = var.listen-port
      to_port          = var.listen-port
      protocol         = "udp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = null
      self             = true
      prefix_list_ids  = null
      security_groups  = null
    }
  ]
  egress      = [
    {
      description      = "Allow all outgoing traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids  = null
      security_groups  = null
      self             = false
    }
  ]
}

resource "aws_security_group" "ec2_vpn_server_ssh" {
  name        = "${local.name}-ec2-vpn-server-ssh"
  description = "allow external access"
  vpc_id      = local.wg_vpc_id
  count       = var.aws_ec2_key != null ? 1 : 0
  ingress     = [
    {
      description      = "ssh if needed"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = null
      self             = true
      prefix_list_ids  = null
      security_groups  = null
    }
  ]
}

resource "aws_eip" "ec2_vpn_instance" {
  vpc  = true
  tags = merge({
    Name = "${local.name}-wireguard"
  })
  lifecycle {
    ignore_changes = [tags]
  }
}

module "ec2_vpn_instance" {
  source                      = "terraform-aws-modules/ec2-instance/aws"
  version                     = "~> v3.3.0"
  iam_instance_profile        = aws_iam_instance_profile.ec2_vpn_server.name
  associate_public_ip_address = true
  name                        = "${local.name}-vpn-server"
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.aws_ec2_key
  monitoring                  = false
  vpc_security_group_ids      = (var.aws_ec2_key == null
  ?  [aws_security_group.ec2_vpn_server.id]
  : [ aws_security_group.ec2_vpn_server.id, aws_security_group.ec2_vpn_server_ssh[0].id ])
  subnet_id                   = local.wg_subnet
  hibernation                 = false
  cpu_credits                 = "unlimited"

  user_data = <<-EOT
Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/usr/bin/bash
set -x
apt-get update
apt-get install -y awscli jq wireguard iptables
sleep 5
systemctl stop wg-quick@wg0.service
REGION=`curl http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'`
aws --region=$REGION lambda invoke --function-name ${module.wg_manage.lambda_function_name} invoke-out.txt
aws --region=$REGION ssm get-parameter --with-decryption --name "${local.wg_ssm_config}" | jq -r .Parameter.Value > /etc/wireguard/wg0.conf
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p
sleep 20
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service
systemctl status wg-quick@wg0.service
#rm /var/lib/cloud/instances/*/sem/config_scripts_user || true
###Setup script to reload WG config
mkdir -p /var/usr/wg-check-reload
cd /var/usr/wg-check-reload
cat > is_reload.sh << 'EOF'
#!/bin/bash
#Get cofig from SSM and compare it with the local config, if SSM has newest version of config - update config and reload service
#Set period of time tolerant to config modification in seconds
GRACE_PERIOD=100
REGION=$(curl http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}')
SSM_LAST_MODIFIED_TIME=$(aws --region=$REGION ssm get-parameter --with-decryption --name "${local.wg_ssm_config}" | jq -r .Parameter.LastModifiedDate | sed -r  's/([0-9]+).([0-9]*)/\1/')
#echo "Last time config modified in SSM:"$SSM_LAST_MODIFIED_TIME
LOCAL_LAST_MODIFIED_TIME=$(stat -c%Z /etc/wireguard/wg0.conf)
#echo "Last time local config modification:"$LOCAL_LAST_MODIFIED_TIME
TIME_DIFF=$(expr $SSM_LAST_MODIFIED_TIME - $LOCAL_LAST_MODIFIED_TIME )
#echo "Time diff:"$TIME_DIFF
if [[  $TIME_DIFF -ge $GRACE_PERIOD ]]
then
    echo "SSM config is newer, reloading WG..."
	aws --region=$REGION ssm get-parameter --with-decryption --name "${local.wg_ssm_config}" | jq -r .Parameter.Value > /etc/wireguard/wg0.conf
	wg syncconf wg0 <(wg-quick strip /etc/wireguard/wg0.conf)
else
	echo "config is pretty new or latest"
fi
EOF
chmod 755 ./is_reload.sh
###Create Systemd Unit to reload wg when config updated
cat > /etc/systemd/system/wg-conf-check-reload.service << 'EOF'
[Unit]
Description=Check WG conf
After=syslog.target network.target

[Service]
Type=oneshot
ExecStart=/var/usr/wg-check-reload/is_reload.sh

[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/wg-conf-check-reload.timer << 'EOF'
[Unit]
Description=Logs some system statistics to the systemd journal
Requires=wg-conf-check-reload.service

[Timer]
Unit=wg-conf-check-reload.service
OnCalendar=*:0/1

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable wg-conf-check-reload.timer
systemctl start wg-conf-check-reload.timer
EOT
}

resource "aws_eip_association" "vpn_server_eip" {
  instance_id   = module.ec2_vpn_instance.id
  allocation_id = aws_eip.ec2_vpn_instance.id
}

resource "aws_ssm_parameter" "wg-instance-id" {
  name        = local.wg_ssm_instance_id
  description = "Wireguard server instance id"
  type        = "String"
  value       = module.ec2_vpn_instance.id
}

output "vpn_external_address" {
  value = aws_eip.ec2_vpn_instance.address
}