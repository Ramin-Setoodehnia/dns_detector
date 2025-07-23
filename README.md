# DNS Detector

A simple Bash script to detect and manage DNS-related services on any Linux server.

## Features

- Detects commonly used DNS services like:
  - `systemd-resolved`
  - `dnsmasq`
  - `bind9`
  - `unbound`
  - `NetworkManager`
  - `resolvconf`
  - and more
- Shows current status (running, installed, etc.)
- Offers actions:
  1. Disable services
  2. Disable and remove services
  3. Exit
- Sets default `/etc/resolv.conf` with:
```text
nameserver 8.8.8.8
nameserver 1.1.1.1
```
## How to Run

```bash
bash <(curl -s https://raw.githubusercontent.com/MrDevAnony/dns_detector/main/dns_detector.sh)
```
