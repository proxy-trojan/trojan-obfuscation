[Unit]
Description=Custom Caddy Front Door
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/caddy-custom run --config /etc/caddy/Caddyfile
Restart=on-failure

[Install]
WantedBy=multi-user.target
