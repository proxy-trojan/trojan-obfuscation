{
  "run_type": "server",
  "local_addr": "$trojan_local_addr",
  "local_port": $trojan_local_port,
  "remote_addr": "127.0.0.1",
  "remote_port": 80,
  "password_env": "$trojan_password_env_key",
  "ssl": {
    "cert": "/etc/trojan-pro/certs/current/edge.crt",
    "key": "/etc/trojan-pro/certs/current/edge.key",
    "sni": "$edge_domain"
  }
}
