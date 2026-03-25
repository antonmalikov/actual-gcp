locals {
  cloud_config = <<-EOT
    #cloud-config
    ${yamlencode({
  write_files = [
    {
      path        = "/etc/systemd/system/caddy.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT2
              [Unit]
              Description=Start Caddy

              [Service]
              ExecStart=/usr/bin/docker run --rm --network custom-bridge -p 443:443 -e CLOUDFLARE_API_TOKEN=${var.cloudflare_token} --mount 'type=bind,source=/mnt/disks/data/caddy/Caddyfile,target=/etc/caddy/Caddyfile,readonly' --mount 'type=bind,source=/mnt/disks/data/caddy/data,target=/data' --mount 'type=bind,source=/mnt/disks/data/caddy/config,target=/config' --name=caddy serfriz/caddy-cloudflare-ddns:latest
              ExecStop=/usr/bin/docker stop caddy
              ExecStopPost=/usr/bin/docker rm caddy
              EOT2
    },
    {
      path        = "/etc/systemd/system/actual.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT3
                  [Unit]
                  Description=Start Actual

                  [Service]
                  ExecStart=/usr/bin/docker run --rm --network custom-bridge -p '[::1]:5006:5006' --mount 'type=bind,source=/mnt/disks/data/actual-data,target=/data' --env-file /mnt/disks/data/.env --name=actual_server actualbudget/actual-server:latest
                  ExecStop=/usr/bin/docker stop actual_server
                  ExecStopPost=/usr/bin/docker rm actual_server
                  EOT3
    },
    {
      path        = "/etc/systemd/system/actualtap.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT7
                  [Unit]
                  Description=Start Actual Tap Service

                  [Service]
                  ExecStart=/usr/bin/docker run --rm --network custom-bridge --mount 'type=bind,source=/mnt/disks/data/actualtap,target=/config' --name=actual_tap ghcr.io/bobokun/actualtap-py:latest

                  ExecStop=/usr/bin/docker stop actual_tap
                  ExecStopPost=/usr/bin/docker rm actual_tap
                  EOT7
    },
    {
      path        = "/etc/systemd/system/actualhttp.service"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT8
                  [Unit]
                  Description=Start Actual Http Api

                  [Service]
                  ExecStart=/usr/bin/docker run --name actual_http --rm --network custom-bridge --mount 'type=bind,source=/mnt/disks/data/actualhttp,target=/data' --env-file /mnt/disks/data/actualhttp/.env jhonderson/actual-http-api:26.3.0
                  ExecStop=/usr/bin/docker stop actual_http
                  ExecStopPost=/usr/bin/docker rm actual_http
                  EOT8
    },
    {
      path        = "/tmp/Caddyfile"
      permissions = "0644"
      owner       = "root"
      content     = <<-EOT4
            {
                dynamic_dns {
                    provider cloudflare {env.CLOUDFLARE_API_TOKEN}
                    domains {
                        ${var.actual_tld} ${var.actual_subdomain}
                    }
                    ip_source simple_http https://icanhazip.com
                    ip_source simple_http https://api64.ipify.org
                    check_interval 1d
                   ttl 5m
                   versions ipv4
               }
            }

            ${var.actual_subdomain}.${var.actual_tld} {
                @actualapi {
                    path /api-docs
                    path /api-docs/*
                    path /v1
                    path /v1/*
                }

                encode gzip zstd
                reverse_proxy /transactions/* actual_tap:8000
                reverse_proxy /transactions actual_tap:8000
                reverse_proxy @actualapi actual_http:5007
                reverse_proxy actual_server:5006
            }


            EOT4
    },
    {
      path        = "/var/lib/cloud/scripts/per-instance/fs-prepare.sh"
      permissions = "0544"
      owner       = "root"
      content     = <<-EOT5
        #!/bin/bash
      
        mkfs.ext4 -L data -m 0 -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/disk/by-id/google-persistent-disk-1
        mkdir -p /mnt/disks/data
        mount -t ext4 -o nodev,nosuid /dev/disk/by-id/google-persistent-disk-1 /mnt/disks/data
        mkdir -p /mnt/disks/data/caddy
        mkdir -p /mnt/disks/data/caddy/data
        mkdir -p /mnt/disks/data/caddy/config
        mkdir -p /mnt/disks/data/actual-data
        mkdir -p /mnt/disks/data/actualhttp
        mkdir -p /mnt/disks/data/actualhttp/data
        mkdir -p /mnt/disks/data/actualtap
        cp /tmp/Caddyfile /mnt/disks/data/caddy/Caddyfile
        cp /tmp/.env /mnt/disks/data/.env
        cp -n /tmp/.http.env /mnt/disks/data/actualhttp/.env
        EOT5
    },
    {
      path        = "/tmp/.env"
      permissions = "0544"
      owner       = "root"
      content     = <<-EOT6
        ACTUAL_OPENID_DISCOVERY_URL=${var.openid_discovery_url}
        ACTUAL_OPENID_CLIENT_ID=${var.openid_clientid}
        ACTUAL_OPENID_CLIENT_SECRET=${var.openid_secret}
        ACTUAL_OPENID_SERVER_HOSTNAME=https://${var.actual_subdomain}.${var.actual_tld}
        ACTUAL_OPENID_ENFORCE=false
        EOT6
    },
    {
      path        = "/tmp/.http.env"
      permissions = "0544"
      owner       = "root"
      content     = <<-EOT9
        ACTUAL_SERVER_URL=http://actual_server:5006/
        ACTUAL_SERVER_PASSWORD=PASSWORD
        API_KEY=KEY
        SWAGGER_HOST=${var.actual_subdomain}.${var.actual_tld}
        SWAGGER_PORT=443
        EOT9
    }
  ]

  runcmd = [
    "docker network create custom-bridge",
    "systemctl daemon-reload",
    "systemctl start caddy.service",
    "systemctl start actual.service",
    "systemctl start actualtap.service",
    "systemctl start actualhttp.service"
  ]

  bootcmd = [
    "fsck.ext4 -tvy /dev/disk/by-id/google-persistent-disk-1",
    "mkdir -p /mnt/disks/data",
    "mount -t ext4 -o nodev,nosuid /dev/disk/by-id/google-persistent-disk-1 /mnt/disks/data",
    "mkdir -p /mnt/disks/data/caddy",
    "mkdir -p /mnt/disks/data/caddy/data",
    "mkdir -p /mnt/disks/data/caddy/config",
    "mkdir -p /mnt/disks/data/actual-data"
  ]
})}
  EOT
}