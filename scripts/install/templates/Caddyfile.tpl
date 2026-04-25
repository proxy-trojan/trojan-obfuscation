:80 {
    redir https://$www_domain{uri}
}

$www_domain {
    tls {
        dns $dns_provider_module
    }
    root * /var/lib/trojan-pro/site
    file_server
}

{
    layer4 {
        :443 {
            @edge tls sni $edge_domain
            route @edge {
                proxy 127.0.0.1:$edge_port
            }
        }
    }
}
