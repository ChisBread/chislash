#coding: utf-8
import yaml
import sys
import os
from collections.abc import Mapping
ext_template = r"""
port: %s
socks-port: %s
redir-port: %s
mixed-port: %s

allow-lan: true
mode: Rule
log-level: %s
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: redir-host
  nameserver:
    - '114.114.114.114'
    - '223.5.5.5'
  fallback:
    - 'tls://1.1.1.1:853'
    - 'tcp://1.1.1.1:53'
    - 'tcp://208.67.222.222:443'
    - 'tls://dns.google'
"""
def deep_update(source, overrides):
    """
    Update a nested dictionary or similar mapping.
    Modify ``source`` in place.
    """
    for key, value in overrides.items():
        if isinstance(value, Mapping) and value:
            returned = deep_update(source.get(key, {}), value)
            source[key] = returned
        else:
            source[key] = overrides[key]
    return source

def override(user_config, ext):
    user = yaml.load(open(user_config, 'r', encoding="utf-8").read(), Loader=yaml.FullLoader)
    deep_update(user, ext)
    user_file = open(user_config, 'w', encoding="utf-8")
    yaml.dump(user, user_file)
    user_file.close()

_,user_config,port,socks_port,redir_port,mixed_port,log_level = sys.argv
override(user_config,yaml.load(ext_template%(port,socks_port,redir_port,mixed_port,log_level), Loader=yaml.FullLoader))
