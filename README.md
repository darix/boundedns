# Unbound dns

## What can the formula do?

Gunbound up and running

## installation

Just add the hook it up like every other formula and do the needed

### Required salt master config:

```
file_roots:
  base:
    [ snip ]
    - {{ formulas_base_dir }}/boundedns/salt/

pillar_roots:
  base:
    [ snip ]
    - {{ formulas_base_dir }}/boundedns/pillar/
```

## cfgmgmt-template integration

if you are using our [cfgmgmt-template](https://codeberg.org/salted-geeko/cfgmgmt-template) as a starting point the saltmaster you can simplify the setup with:

```
git submodule add https://codeberg.org/salted-geeko/boundedns formulas/boundedns
ln -s /srv/cfgmgmt/formulas/boundedns/config/enable_boundedns.conf /etc/salt/master.d/
systemctl restart saltmaster
```

## How to use

Follow pillar.example for your pillar settings.

## License

[AGPL-3.0-only](https://spdx.org/licenses/AGPL-3.0-only.html)

[0]: https://build.opensuse.org/package/show/home:darix:apps/nftables-service