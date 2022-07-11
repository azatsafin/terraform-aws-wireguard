import wgconfig
import os
import wgconfig.wgexec as wgexec
import boto3
import ipaddress
import json
from botocore.config import Config

boto3_conf = Config(read_timeout=10, retries={"total_max_attempts": 2})
aws_iam = boto3.client('iam', config=boto3_conf)
aws_ssm = boto3.client('ssm', config=boto3_conf)
aws_ec2 = boto3.client('ec2', config=boto3_conf)
aws_lambda = boto3.client('lambda', config=boto3_conf)

user_ssm_prefix = os.getenv('WG_SSM_USERS_PREFIX')
wg_subnet = os.getenv('WG_SUBNET')
wg_config_ssm_path = os.getenv('WG_SSM_CONFIG_PATH')
wg_listen_port = os.getenv('WG_LISTEN_PORT')
wg_public_ip = os.getenv('WG_PUBLIC_IP')
vpc_cidr = os.getenv('VPC_CIDR')
wg_routed_subnets = os.getenv('WG_ROUTED_SUBNETS')

def get_ssm_attrs(ssm_path):
    try:
        wg_ssm_config = aws_ssm.get_parameter(Name=ssm_path, WithDecryption=True)
    except Exception as e:
        return None
    if 'Parameter' in wg_ssm_config:
        return wg_ssm_config['Parameter']['Value'].split('\n')
    else:
        return None


def get_existing_users():
    def get_next_item(next_token):
        if next_token is None:
            request_params = {
                "Path": user_ssm_prefix,
                "Recursive": False,
                "WithDecryption": True
            }
        else:
            request_params = {
                "Path": user_ssm_prefix,
                "Recursive": False,
                "WithDecryption": True,
                "NextToken": next_token
            }
        ssm_users = []
        try:
            ssm_users_resp = aws_ssm.get_parameters_by_path(**request_params)
        except Exception as e:
            return None
        for user in ssm_users_resp['Parameters']:
            ssm_users.append(user['Name'].split('/')[-1])
        if 'NextToken' in ssm_users_resp:
            ssm_users += get_next_item(ssm_users_resp['NextToken'])
        return ssm_users
    return get_next_item(None)


def add_user(ssm_users, user, wg_conf):
    if user['id'] not in ssm_users:
        existing_users = set(ssm_users)
        available_ips = free_ip(existing_users)
        private_key = wgexec.generate_privatekey()
        ip_address = available_ips.pop()
        server_public_key = wgexec.get_publickey(wg_conf.interface['PrivateKey'])
        user_conf = {"address": ip_address.__str__(), "private_key": private_key,
                     "public_key": wgexec.get_publickey(private_key)}
        wg_conf_user = wgconfig.WGConfig(str(user['id']) + "/" + user['login'])
        wg_conf_user.add_attr(None, 'PrivateKey', private_key)
        wg_conf_user.add_attr(None, 'Address', ip_address.__str__() + "/32")
        wg_conf_user.add_attr(None, 'DNS', (ipaddress.IPv4Network(wg_subnet).network_address + 1).__str__())
        wg_conf_user.add_peer(server_public_key)
        wg_conf_user.add_attr(server_public_key, 'AllowedIPs', wg_routed_subnets + ", " +
                              str(ipaddress.IPv4Network(wg_subnet).network_address + 1))
        wg_conf_user.add_attr(server_public_key, 'Endpoint', str(wg_public_ip) + ":" + wg_listen_port)
        user_conf["ClientConf"] = "{}".format("\n".join(wg_conf_user.lines))
        new_ssm_param = aws_ssm.put_parameter(
            Name=user_ssm_prefix + "/" + str(user['id']),
            Description='Wireguard peer conf for user:{}'.format(str(user['id']) + "/" + user['login']),
            Value=json.dumps(user_conf),
            Type='SecureString',
            Overwrite=True,
            Tier='Standard',
            DataType='text'
        )
        return True
    else:
        return False

def add_users_to_wg_config(wg_conf, users):
    # Create peers section
    for user in users:
        peer_conf = json.loads(get_ssm_attrs(user_ssm_prefix + "/" + user)[0])
        wg_conf.add_peer(wgexec.get_publickey(peer_conf['private_key']), "#{}".format(user))
        wg_conf.add_attr(wgexec.get_publickey(peer_conf['private_key']), 'AllowedIPs', peer_conf['address'] + "/32")
    return wg_conf

def remove_users(users):
    for user in users:
        print("Removing ssm param for user:{}".format(user))
        aws_ssm.delete_parameter(Name=user_ssm_prefix + "/" + user)
    return True


def free_ip(remaining_users):
    ip_all = set(ipaddress.IPv4Network(wg_subnet).hosts()) - {ipaddress.IPv4Network(wg_subnet).network_address + 1}
    for user in remaining_users:
        user_attributes = aws_ssm.get_parameter(Name=user_ssm_prefix + "/" + user, WithDecryption=True)
        ip_all = ip_all - {ipaddress.IPv4Address(json.loads(user_attributes['Parameter']['Value'])['address'])}
    return ip_all


def read_wg_config():
    wg_ssm_config = get_ssm_attrs(wg_config_ssm_path)
    if wg_ssm_config is not None:
        wc = wgconfig.WGConfig('wg0')
        wc.lines = wg_ssm_config
        wc.parse_lines()
        return wc
    else:
        # wg config not found, let create it
        return None


def create_new_wg_conf():
    server_ip = (ipaddress.IPv4Network(wg_subnet).network_address + 1).__str__()
    server_private_key = wgexec.generate_privatekey()
    wg_conf = wgconfig.WGConfig('wg0')
    wg_conf.add_attr(None, 'PrivateKey', server_private_key)
    wg_conf.add_attr(None, 'Address', server_ip + "/" + str(ipaddress.IPv4Network(wg_subnet).prefixlen))
    wg_conf.add_attr(None, 'ListenPort', wg_listen_port)
    # Construct internal dns server address
    vpc_dns_address = (ipaddress.IPv4Network(vpc_cidr).network_address + 2).__str__()
    # Set which subnets must be passed trough NAT, for simpler explanation enable routing for, by default 0.0.0.0/0
    nat_rules = ""
    for rule in wg_routed_subnets.replace(" ", "").split(","):
        nat_rules = nat_rules + "iptables -t nat -A POSTROUTING -d {0} -o ens5 -j MASQUERADE; ".format(rule)
    # Following section needed to use internal AWS DNS,
    # this enable access to AWS resources by the names which doesn't have external resolution/IP
    wg_conf.add_attr(None, 'PostUp', 'iptables -A FORWARD -i %i -j ACCEPT; '
                                     'iptables -A FORWARD -o %i -j ACCEPT; '
                                     '{1}'
                                     'iptables -A PREROUTING -t nat -i %i -p udp --dport 53  -j DNAT --to-destination {0}; '
                                     'iptables -A PREROUTING -t nat -i %i -p tcp --dport 53  -j DNAT --to-destination {0}'
                     .format(vpc_dns_address, nat_rules))
    wg_conf.add_attr(None, 'PostDown', 'iptables -D FORWARD -i %i -j ACCEPT; '
                                       'iptables -D FORWARD -o %i -j ACCEPT; '
                                       '{1}'
                                       'iptables -D PREROUTING -t nat -i %i -p udp --dport 53  -j DNAT --to-destination {0}; '
                                       'iptables -D PREROUTING -t nat -i %i -p tcp --dport 53  -j DNAT --to-destination {0}'.
                     format(vpc_dns_address, nat_rules))
    return wg_conf


def get_wg_config():
    wg_conf_old = read_wg_config()
    if wg_conf_old is None:
        wg_conf = create_new_wg_conf()
    else:
        wg_conf = wg_conf_old
        for peer in wg_conf.peers:
            wg_conf.del_peer(peer)
    return wg_conf


def handler(event, context):
    if not event['action'] or not event['user'] or not event['user']['id']:
        return {
            "Error": "missing required request params"
        }
    wg_conf = get_wg_config()
    ssm = get_existing_users()
    user = event['user']
    if event['action'] == 'member_added':
        print("Users to add:{}".format(user))
        if add_user(ssm, user, wg_conf):
            ssm.append(str(user['id']))
        else:
            return {
                "Error": "can't add user:{}".format(user)
            }
    elif event['action'] == 'member_removed':
        if remove_users([str(user['id'])]):
            ssm.remove(str(user['id']))
    else:
        return {
            "Error": "User:{} already exist".format(user)
        }
    wg_conf_new = add_users_to_wg_config(wg_conf, ssm)
    aws_ssm.put_parameter(
        Name=wg_config_ssm_path,
        Description='Wireguard server conf',
        Value="{}".format("\n".join(wg_conf_new.lines)),
        Type='SecureString',
        Overwrite=True,
        Tier='Advanced',
        DataType='text'
    )