[Unit]
Description=Trojan Pro
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/trojan -c /etc/trojan-pro/config.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
