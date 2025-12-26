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