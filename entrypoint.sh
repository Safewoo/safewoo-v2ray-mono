#!/bin/bash

set -e

echoinfo(){
    echo -e "\033[32m$1\033[0m"
}

echoerr(){
    echo -e "\033[31m$1\033[0m"
}

DEFAULT_API="https://api.safewoo.com/next/v1/script"
SSL_CRT_PATH="/opt/safewoo/$DOMAIN.crt"
SSL_KEY_PATH="/opt/safewoo/$DOMAIN.key"
V2RAY_CONF="/opt/v2ray/config.json"

config_nginx(){
    cat > /etc/nginx/conf.d/v2fly.conf << EOF
server {
    server_name $DOMAIN;
    listen 443 ssl http2;

    ssl_certificate $SSL_CRT_PATH;
    ssl_certificate_key $SSL_KEY_PATH;
    ssl_protocols TLSv1.2;
    add_header Strict-Transport-Security "max-age=63072000" always;
    access_log /var/log/nginx/access.v2ray.log;
    error_log /var/log/nginx/error.v2ray.log;

    location $URL_PATH {
            proxy_pass http://127.0.0.1:1080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-Ip \$remote_addr;
    }

    location / {
            return 403;
    }
}
EOF
    /usr/sbin/nginx -t || (echo "nginx test failed"; exit 1)
    echo "Nginx is configured"
}

conf_supervisor(){
    cat > /etc/supervisor/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=NONE

[program:v2ray]
process_name=%(program_name)s
command=/opt/v2ray/v2ray run -c /opt/v2ray/config.json
autostart=true
autorestart=true
startretries=10
stdout_logfile=NONE
stderr_logfile=NONE

[program:nginx]
process_name=%(program_name)s
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
startretries=10
stdout_logfile=NONE
stderr_logfile=NONE
EOF
    echo "Supervisor is configured"
}

make_vmess_inbound(){
    cat > /tmp/_v2ray_inbound << EOF
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "$PROTOCOL",
      "settings": {
        "clients": [
          {
            "id": "$SECRET",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$URL_PATH",
          "headers": {
            "Host": "$DOMAIN"
          }
        }
      },
      "tag": "safewoo-inbound",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "allocate": {
        "strategy": "always",
        "refresh": 5,
        "concurrency": 3
      }
    }
EOF
}

make_ss_inbound(){
    
    cat > /tmp/_v2ray_inbound << EOF
  {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "shadowsocks",
      "settings": {
        "password": "$SECRET",
        "method": "aes-128-gcm",
        "level": 0,
        "network": "tcp",
        "ivCheck": true,
        "packetEncoding": "None"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/$URL_PATH",
          "headers": {
            "Host": "$DOMAIN"
          }
        }
      },
      "tag": "safewoo-inbound",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "allocate": {
        "strategy": "always",
        "refresh": 5,
        "concurrency": 3
      }
    }
EOF
}

make_trojan_inbound(){
    
    cat > /tmp/_v2ray_inbound << EOF
    {
      "port": 1080,
      "listen": "0.0.0.0",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$SECRET",
            "level": 0
          }
        ],
        "packetEncoding": "None"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$URL_PATH",
          "headers": {
            "Host": "$DOMAIN"
          }
        }
      },
      "tag": "safewoo-inbound",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "allocate": {
        "strategy": "always",
        "refresh": 5,
        "concurrency": 3
      }
    }
EOF
}


make_v2ray_conf(){
    
    # make inbound config based on PROTOCOL
    case $PROTOCOL in
        vmess)
            make_vmess_inbound
        ;;
        ss)
            make_ss_inbound
        ;;
        trojan)
            make_trojan_inbound
        ;;
        *)
            echo "PROTOCOL is not supported"
            exit 1
        ;;
    esac
    
    # read /tmp/_v2ray_inbound and set V2RAY_INBOUND
    
    V2RAY_INBOUND=$(cat /tmp/_v2ray_inbound)
    
    cat > $V2RAY_CONF << EOF
{
  "log": {
    "access": "/var/log/v2fly.log",
    "loglevel": "info"
  },
  "inbounds": [
    $V2RAY_INBOUND
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-ads"
        ],
        "outboundTag": "blocked"
      }
    ]
  },
  "dns": {
    "servers": [
      "1.1.1.1",
      {
        "address": "114.114.114.114",
        "port": 53,
        "domains": [
          "geosite:cn"
        ]
      },
      "8.8.8.8",
      "localhost"
    ]
  },
  "policy": {
    "levels": {
      "0": {
        "uplinkOnly": 0,
        "downlinkOnly": 0
      }
    },
    "system": {
      "statsInboundUplink": false,
      "statsInboundDownlink": false,
      "statsOutboundUplink": false,
      "statsOutboundDownlink": false
    }
  },
  "other": {}
}
EOF
}

output_client_config(){
  # args: client=clash|v2ray
  CLIENT=$1
  # v2ray file name `/tmp/v2ray.client.json`, clash file name `/tmp/clash.yml`
  if [ "$CLIENT" == "v2ray" ]; then
    outfile="/tmp/v2ray.client.json"
  else
    outfile="/tmp/clash.yml"
  fi

  echo "Generating client config..."

  curl -X POST -d "client=$CLIENT&domain=$DOMAIN&path=$URL_PATH&protocol=$PROTOCOL&secret=$SECRET" \
    $SW_API/client-config/ -o $outfile > /dev/null 2>&1
  
  echo "Client config is generated"
  echoinfo "******************************* Client Config ******************************************"
  cat $outfile
  echoinfo "****************************************************************************************"
}


issue_certificate(){
    
    # create if not exsits /opt/safewoo/
    if [ ! -d /opt/safewoo ]; then
        mkdir -p /opt/safewoo
    fi
    
    # issue a self-signed certificate that commnan name is $DOMAIN
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $SSL_KEY_PATH -out $SSL_CRT_PATH -subj "/CN=$DOMAIN"
    echo "Certificate is issued"
}

check_certificate(){
    # issue a self-signed certificate if not available
    if [ ! -f $SSL_CRT_PATH ] || [ ! -f $SSL_KEY_PATH ]; then
        echo "Certificate is not available, issuing a self-signed certificate."
        issue_certificate
    fi
    
    # Check the certificate with openssl, make sure it is available and fit for the domain
    openssl x509 -in $SSL_CRT_PATH -noout -text | grep -q "CN = $DOMAIN"
    if [ $? -ne 0 ]; then
        echo "Error: Certificate $SSL_CRT_PATH is not valid for the domain $DOMAIN."
        exit 1
    fi
    
    echo "Assets are available and the certificate is valid for the domain $DOMAIN."
}

start(){
    /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
    echo "Supervisor started"
}

main(){
    
    # example:
    # podman run -e DOMAIN=example.com -e URL_PATH=/v2 -e PROTOCOL=vmess -e SECRET=123456  \
    # -v /opt/safewoo:/opt/safewoo \
    # -p 6000:443 -d safewoo/v2fly-mono:latest
    #
    
    # check env variables DOMAIN, URL_PATH, SECRET, PROTOCOL
    DOMAIN=${DOMAIN}
    URL_PATH=${URL_PATH}
    PROTOCOL=${PROTOCOL}
    SECRET=${SECRET}
    TOKEN=${TOKEN}
    SW_API=${SW_API}

    # if not DOMAIN, make a radom sub of safewoo.com
    if [ -z "$DOMAIN" ]; then
        SUB=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 4 | head -n 1)
        ZONE=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 4 | head -n 1)
        DOMAIN="$SUB.$ZONE.com"
    fi
    
    # default PROTOCOL is vmess
    if [ -z "$PROTOCOL" ]; then
        PROTOCOL="vmess"
    fi
    
    # if not URL_PATH, make a radom path
    if [ -z "$URL_PATH" ]; then
        URL_PATH="/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)"
    fi
    
    # if not SECRET, make a random secret, if protocal is vmess, make a random uuid
    if [ -z "$SECRET" ]; then
        if [ "$PROTOCOL" == "vmess" ]; then
            SECRET=$(cat /proc/sys/kernel/random/uuid)
        else
            SECRET=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
        fi
    fi

    # if not SW_API, use default api
    if [ -z "$SW_API" ]; then
        SW_API=$DEFAULT_API
    fi
    
    echoinfo "******************************* Config ******************************************"
    echoinfo "DOMAIN: $DOMAIN"
    echoinfo "URL_PATH: $URL_PATH"
    echoinfo "PROTOCOL: $PROTOCOL"
    echoinfo "SECRET: $SECRET"
    echoinfo "*********************************************************************************"
    
    check_certificate
    config_nginx
    conf_supervisor
    make_v2ray_conf
    output_client_config
    start
}

main