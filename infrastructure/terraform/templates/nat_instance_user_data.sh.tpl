dnf -y install iptables-services

cat >/etc/sysctl.d/99-nat.conf <<'EOF'
net.ipv4.ip_forward = 1
EOF

sysctl --system

cat >/etc/sysconfig/iptables <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
-A FORWARD -m conntrack --ctstate INVALID -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "NAT_INVALID " --log-level 4
-A FORWARD -m conntrack --ctstate INVALID -j DROP
-A FORWARD -i eth0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
-A FORWARD -s ${PRIVATE_SUBNET_CIDR} -o eth0 -j ACCEPT
-A FORWARD -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "NAT_UNMATCHED " --log-level 4
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
