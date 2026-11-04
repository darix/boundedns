#!py
#
# boundedns
#
# Copyright (C) 2025   darix
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

from salt.exceptions import SaltConfigurationError, SaltRenderError
import logging
import ipaddress
log = logging.getLogger("boundedns")

unbound_default_files = [
  "/etc/unbound/conf.d",
  "/etc/unbound/conf.d/example.com.conf" ,
  "/etc/unbound/keys.d",
  "/etc/unbound/keys.d/example.com.key",
  "/etc/unbound/local.d",
  "/etc/unbound/local.d/block-example.com.conf",
  "/etc/unbound/unbound.conf",
]

def ensure_trailing_dot(entry):
  if not entry.endswith('.'):
    entry = f"{entry}."
  return entry

def run():
  config = {}
  unbound_pillar = __salt__['pillar.get']('unbound', {})
  use_apparmor = unbound_pillar.get('use_apparmor', False)

  unbound_packages = ['unbound', 'python3-unbound']
  # if use_apparmor:
  #   unbound_packages.append("unbound-apparmor")

  unbound_config_dir = '/etc/unbound'
  unbound_service  = 'unbound.service'

  if len(unbound_pillar) > 0 and unbound_pillar.get('enabled', True):
    config["unbound_packages"] = {
      'pkg.installed': [
        {'pkgs': unbound_packages}
      ]
    }

    unbound_service_deps = ["unbound_checkconf", "unbound_service"]

    for config_subdir, config_files in unbound_pillar.get('config', {}).items():
      if config_subdir not in ["conf.d", "local.d"]:
        raise SaltConfigurationError("only 'conf.d' and 'local.d' are supported as subdirs")

      for config_file_name, config_data in config_files.items():

        config_content = ""

        if isinstance(config_data, str):
          config_content = config_data
        elif isinstance(config_data, list):
          config_content = "\n".join(config_data)
        else:
          raise SaltConfigurationError(f"only lists and strings are supported for the config content. got {type(config_data)}")

        config[f"unbound_config_{config_subdir}_{config_file_name}"] = {
          "file.managed": [
            {'name':      f"{unbound_config_dir}/{config_subdir}/{config_file_name}.conf"},
            {'user':      'root'},
            {'group':     'unbound'},
            {'mode':      '0640'},
            {'contents':   config_content},
            {'require':    ["unbound_packages"]},
            {'require_in': unbound_service_deps},
            {'watch_in':   unbound_service_deps},
          ]
        }

    if "local_dns" in unbound_pillar:
      local_dns_pillar = unbound_pillar.get('local_dns', {})
      local_dns_content = ['# salt managed', 'server:']

      default_overall_ttl = 3600
      default_record_ttl  = local_dns_pillar.get('default_ttl', default_overall_ttl)
      auto_ptr            = local_dns_pillar.get('auto_ptr', True)

      soa_settings = local_dns_pillar.get('soa', {})

      soa_default_primaryns    = soa_settings.get('primaryns',    __salt__['grains.get']('fqdn'))
      soa_default_rname        = soa_settings.get('rname',        'badly.configured.dns')
      soa_default_serial       = soa_settings.get('serial',        0)

      soa_default_ttl          = soa_settings.get('ttl',          default_overall_ttl)
      soa_default_negative_ttl = soa_settings.get('negative_ttl', default_overall_ttl)
      soa_default_retry        = soa_settings.get('retry',        default_overall_ttl)
      soa_default_refresh      = soa_settings.get('refresh',      default_overall_ttl)
      soa_default_expire       = soa_settings.get('expire',       3600000)

      for zone_name, zone_data in local_dns_pillar.get('zones', {}).items():
    # $TTL 86400
    # @   IN  SOA     ns.icann.org. noc.dns.icann.org. (
    #         2020080302  ;Serial
    #         7200        ;Refresh
    #         3600        ;Retry
    #         1209600     ;Expire
    #         3600        ;Negative response caching TTL
    # )
        local_soa_data = zone_data.get('soa', {})

        soa_ns           = local_soa_data.get('primaryns',    soa_default_primaryns)
        soa_rname        = local_soa_data.get('rname',        soa_default_rname)
        soa_serial       = local_soa_data.get('serial',       soa_default_serial)
        soa_ttl          = local_soa_data.get('ttl',          soa_default_ttl)
        soa_negative_ttl = local_soa_data.get('negative_ttl', soa_default_negative_ttl)
        soa_retry        = local_soa_data.get('retry',        soa_default_retry)
        soa_refresh      = local_soa_data.get('refresh',      soa_default_refresh)
        soa_expire       = local_soa_data.get('expire',       soa_default_expire)

        zone_type = zone_data.get('type', 'static')
        local_dns_content.append(f'  local-zone: "{zone_name}" {zone_type}')
        local_dns_content.append(f'  local-data: "{zone_name} {soa_ttl} IN SOA {soa_ns} {soa_rname} {soa_serial} {soa_refresh} {soa_retry} {soa_expire} {soa_negative_ttl}"')

      for entry, entry_data in local_dns_pillar.get('entries', {}).items():
        entry_with_dot = ensure_trailing_dot(entry)
        for entry_type, entry_value in entry_data.items():
          entry_type_str = entry_type.upper()
          if "cname" == entry_type:
            for value in entry_value:
              value_with_dot = ensure_trailing_dot(value)
              local_dns_content.append(f'  local-data: "{value_with_dot} {default_record_ttl} IN {entry_type_str} {entry_with_dot}"')
          else:
              local_dns_content.append(f'  local-data: "{entry_with_dot} {default_record_ttl} IN {entry_type_str} {entry_value}"')
          if auto_ptr and entry_type in ['a', 'aaaa']:
            ip_address = ipaddress.ip_address(entry_value)
            if not ip_address.is_link_local:
              ptr = ensure_trailing_dot(ip_address.reverse_pointer)
              local_dns_content.append(f'  local-data: "{ptr} {default_record_ttl} IN PTR {entry_with_dot}"')

      config_subdir = 'conf.d'
      config_file_name = 'local_dns_salt'
      config_content = "\n".join(local_dns_content)
      config[f"unbound_config_{config_subdir}_{config_file_name}"] = {
        "file.managed": [
          {'name':      f"{unbound_config_dir}/{config_subdir}/{config_file_name}.conf"},
          {'user':      'root'},
          {'group',     'unbound'},
          {'mode':      '0640'},
          {'contents':   config_content},
          {'require':    ["unbound_packages"]},
          {'require_in': unbound_service_deps},
          {'watch_in':   unbound_service_deps},
          {'onchanges_in': unbound_service_deps},
        ]
      }
    config["unbound_checkconf"] = {
      'cmd.run': [
        {'name': '/sbin/unbound-checkconf'},
        {'require': ["unbound_packages"]},
      ],
    }

    config["unbound_service"] = {
      f'service.{unbound_pillar.get("service_state", "running")}': [
        {'name': unbound_service},
        {'require': ["unbound_checkconf"]},
        {'enable': True},
      ],
    }
  else:
    config["unbound_service"] = {
      "service.dead": [
        {'name': unbound_service},
        {'require_in': ["unbound_packages"] },
      ]
    }
    config["unbound_packages"] = {
      'pkg.purged': [
        {'pkgs': unbound_packages}
      ]
    }

  return config
