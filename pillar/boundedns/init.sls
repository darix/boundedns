step:
  certificates:
    host:
      generic:
        acls_for_combined_file:
          - acl_type: user
            acl_names:
            - unbound
        affected_services:
          - unbound.service

unbound:
  config:
    conf.d:
      001-common: |-
        server:
          module-config: "validator cachedb iterator"
          edns-tcp-keepalive: 'yes'
          prefetch: 'yes'
          serve-expired: 'yes'
          serve-expired-ttl: 86400  # one day, in seconds
          serve-expired-client-timeout: 0  # for version 1.23.0 and latter
          num-threads: 4
          outgoing-range: 8192
          num-queries-per-thread: 4096
          # more cache memory, rrset=msg*2
          rrset-cache-size: 100m
          msg-cache-size: 50m

          # more outgoing connections
          # depends on number of cores: 1024/cores - 50
          outgoing-range: 950

          # Larger socket buffer.  OS may need config.
          so-rcvbuf: 4m
          so-sndbuf: 4m

          # Faster UDP with multithreading (only on Linux).
          so-reuseport: yes

          aggressive-nsec: yes
          tls-ciphers: "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305"
          tls-cert-bundle: "/etc/ssl/ca-bundle.pem"
          tls-service-key: /etc/step/certs/generic.host.full.pem
          tls-service-pem: /etc/step/certs/generic.host.full.pem
          hide-identity: yes
          hide-version: yes
          val-log-level: 2
          log-queries: yes
          qname-minimisation: no
          trusted-keys-file: ""
          auto-trust-anchor-file: ""

      003-remote-control: |-
        remote-control:
          # Enable remote control with unbound-control(8) here.
          # set up the keys and certificates with unbound-control-setup.
          # Note: required for unbound-munin package
          control-enable: yes

          # what interfaces are listened to for remote control.
          # give 0.0.0.0 and ::0 to listen to all interfaces.
          # control-interface: 127.0.0.1
          # control-interface: ::1

          # port number for remote control operations.
          control-port: 50953

          # unbound server key file.
          server-key-file: "/etc/step/certs/generic.host.full.pem"

          # unbound server certificate file.
          server-cert-file: "/etc/step/certs/generic.host.full.pem"

          # unbound-control key file.
          control-key-file: "/etc/step/certs/generic.host.full.pem"

          # unbound-control certificate file.
          control-cert-file: "/etc/step/certs/generic.host.full.pem"
