FROM debian:stable-slim

RUN apt-get update && apt-get install -y bash supervisor nginx openssl curl gettext jq \
    && rm -rf /var/lib/apt/lists/*

COPY ./v2ray /opt/v2ray
RUN chmod +x /opt/v2ray/v2ray

COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh 
# RUN chmod +x /opt/safewoo/entrypoint.sh

ENV DOMAIN=${DOMAIN} 
ENV URL_PATH=${URL_PATH}
ENV SECRET=${SECRET}
ENV PROTOCOL=${PROTOCOL}

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]

# example: 
# podman run -e DOMAIN=example.com -e URL_PATH=/v2 -e PROTOCOL=vmess -e SECRET=123456  \
# -v /opt/safewoo:/opt/safewoo \
# -p 6000:443 -d ghcr.io/safewoo/v2fly-mono:latest