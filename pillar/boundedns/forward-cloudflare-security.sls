unbound:
  config:
    conf.d:
      002-forwarders: |-
        forward-zone:
          name: "."
          forward-tls-upstream: yes               # use DNS-over-TLS forwarder
          forward-first: no                       # do NOT send direct

          # https://developers.cloudflare.com/1.1.1.1/ip-addresses/
          #
          # forward-addr: 1.1.1.1#one.one.one.one
          # forward-addr: 1.0.0.1#one.one.one.one
          # forward-addr: 2606:4700:4700::1111#one.one.one.one
          # forward-addr: 2606:4700:4700::1001#one.one.one.one
          #
          forward-addr:              1.1.1.2#security.cloudflare-dns.com
          forward-addr:              1.0.0.2#security.cloudflare-dns.com
          forward-addr: 2606:4700:4700::1112#security.cloudflare-dns.com
          forward-addr: 2606:4700:4700::1002#security.cloudflare-dns.com
          #
          # forward-addr:              1.1.1.3#family.cloudflare-dns.com
          # forward-addr:              1.0.0.3#family.cloudflare-dns.com
          # forward-addr: 2606:4700:4700::1113#family.cloudflare-dns.com
          # forward-addr: 2606:4700:4700::1003#family.cloudflare-dns.com
