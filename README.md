# SafeWoo V2Ray Mono

SafeWoo V2Ray Mono is the deployment executor of the [safewoo.com](https://safewoo.com)

## Table of Contents
- [Introduction](#introduction)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Troubleshooting](#troubleshooting)

## Introduction

SafeWoo V2Ray Mono is a Docker-based deployment solution for setting up a V2Ray instance with a WebSocket stream and an Nginx proxy pass. This project aims to simplify the process of deploying a secure and efficient V2Ray server.

Safewoo.com uses it in production.

The easiest way to use it.

```bash
curl -fsSL https://safewoo.com/v2ray.sh | sudo bash -s -- -p vless
```


## Installation

To install SafeWoo V2Ray Mono, pull it from github

```bash
docker pull ghcr.io/safewoo/safewoo-v2ray-mono:release
```

or clone the repository and build the Docker image. 

```bash
git clone git@github.com:Safewoo/safewoo-v2ray-mono.git
docker build -t safewoo-v2ray-mono .
```

### Features

- **WebSocket Stream**: Utilizes WebSocket for secure and efficient data transmission.
- **Nginx Proxy**: Configures Nginx to proxy pass requests to the V2Ray service, enhancing security and performance.
- **Self-Signed Certificates**: Automatically generates self-signed SSL certificates for secure communication.
- **Protocol Support**: Supports multiple protocols including `vmess`, `trojan`, and `shadowsocks`.
- **Easy Configuration**: Environment variables are used to configure the domain, protocol, secret, and URL path.

### Why Use SafeWoo V2Ray Mono?

- **Security**: Ensures secure communication with SSL/TLS encryption.
- **Simplicity**: Simplifies the deployment process with Docker and automated scripts.
- **Flexibility**: Supports multiple protocols and can be easily customized to fit different use cases.
- **Reliability**: Uses Supervisor to manage and monitor the V2Ray and Nginx processes, ensuring high availability.

## Usage
To start using SafeWoo V2Ray Mono, run the following command:

```bash
docker run -p 443:443 --name safewoo-v2ray-mono -d ghcr.io/safewoo/safewoo-v2ray-mono:release 
```

This will run a Vmess service behind Nginx, using a random HTTP path, random domain name, and random UUID (password).

To view the client configuration, run the following command:

```bash
docker logs safewoo-v2ray-mono 
```

### Use trusted ssl certificate

Assuming you have a certificate pair in `/your-cert-dir/example.com.key` and `/your-cert-dir/example.com.crt`

```bash
docker run -e DOMAIN=example.com \
    -e SECRET=secret_of_inbound \
    -e PROTOCOL=${vmess|trojan|ss} \
    -e URL_PATH=/a_path_no_one_knows \
    -v /your-cert-dir:/opt/safewoo \
    --name safewoo-v2ray-mono \
    -p 443:443 -d ghcr.io/safewoo/safewoo-v2ray-mono:release
```

### Use self-signed certificate

If there is no certificate directory mounted to /opt/safewoo, a self-signed certificate will be issued. The container issued a self-signed certificate, which is a security risk and may be blocked by firewalls. Safewoo WebShell offers a solution by creating a secure reverse proxy with a certificate from a trusted Certificate Authority (CA) and a real domain name. This significantly enhances security, improves accessibility, and helps bypass censorship.

```bash
docker run -e DOMAIN=example.com \
    -e SECRET=secret_of_inbound \
    -e PROTOCOL=${vmess|trojan|ss} \
    -e URL_PATH=/a_path_no_one_knows \
    --name safewoo-v2ray-mono \
    -p 443:443 -d ghcr.io/safewoo/safewoo-v2ray-mono:release
```

### All env variables

- DOMAIN: The domain name used in the Nginx server name and SSL certificate. If not set, a random value will be generated.
- URL_PATH: The URL path that Nginx proxies. If not set, a random value will be generated.
- PROTOCOL: The protocol to be used. Options are `vmess`, `trojan`, or `ss`.
- SECRET: The UUID for `vmess`, or the password for `trojan` and `ss`.
- DISABLE_ONLINE_CONFIG: If set, Safewoo.com will not receive the information generated by the container, and no online config page will be available.

## Contributing
We welcome contributions! Please read our [contributing guidelines](CONTRIBUTING.md) to get started.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Troubleshooting
If you encounter any issues, please check the following:

- Ensure that your domain is correctly pointed to your server.
- Verify that the Docker container is running and listening on the correct ports.
- Check the logs for any error messages.