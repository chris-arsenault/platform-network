#!/bin/bash
set -euo pipefail

dnf install -y iptables-services

cat >/etc/sysctl.d/99-nat.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF

sysctl --system

cat >/etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s ${PRIVATE_SUBNET_CIDR} -o eth0 -j ACCEPT
COMMIT
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -o eth0 -j MASQUERADE
COMMIT
EOF

systemctl enable --now iptables
