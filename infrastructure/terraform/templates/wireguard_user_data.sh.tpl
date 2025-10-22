#!/bin/bash
set -euxo pipefail

echo "NEW DATA 2"
WG_PORT="${WG_PORT}"
WG_CIDR="${WG_CIDR}"
WG_CIDR_HOST="${WG_CIDR_HOST}"
HOME_LAN="${HOME_LAN_CIDR}"
LAPTOP_PUB="${LAPTOP_PEER_PUBKEY}"
HOME_PUB="${HOME_PEER_PUBKEY}"
PRIVATE_SUBNET="${PRIVATE_SUBNET_CIDR}"
SSM_PUBLIC_KEY_PATH="${SSM_PUBLIC_KEY_PATH}"
AWS_REGION="${AWS_REGION}"
SECRET_ID="${SECRET_ID}"

# Install WireGuard + helpers
dnf -y install wireguard-tools iproute iptables-services jq awscli

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.d/99-wg.conf
sysctl -p /etc/sysctl.d/99-wg.conf
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

# Fetch current secret value
JSON=$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$SECRET_ID" --query SecretString --output text || echo "")
if [ -z "$JSON" ] || [ "$JSON" = "null" ]; then
  # Shouldn't happen (Terraform creates it), but be resilient
  JSON='{"private":"PLACEHOLDER","public":"PLACEHOLDER"}'
fi

PRIV=$(echo "$JSON" | jq -r '.private')
PUB=$(echo  "$JSON" | jq -r '.public')

if [ "$PRIV" = "PLACEHOLDER" ] || [ -z "$PRIV" ] || [ "$PRIV" = "null" ]; then
  # Generate new persistent keypair and write back to the existing secret (no CreateSecret)
  umask 077
  wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
  PRIV="$(cat /etc/wireguard/server_private.key)"
  PUB="$(cat /etc/wireguard/server_public.key)"
  aws secretsmanager put-secret-value \
    --region "$AWS_REGION" --secret-id "$SECRET_ID" \
    --secret-string "$(jq -n --arg priv "$PRIV" --arg pub "$PUB" '{private:$priv,public:$pub}')"
else
  # Use the persisted keys
  umask 077
  printf "%s" "$PRIV" > /etc/wireguard/server_private.key
  printf "%s" "$PUB"  > /etc/wireguard/server_public.key
fi
chmod 600 /etc/wireguard/server_private.key

SERVER_PRIV=$(cat /etc/wireguard/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/server_public.key)

# Persist server public key to SSM Parameter Store (so TF can output it)
/usr/bin/aws ssm put-parameter \
  --name "${SSM_PUBLIC_KEY_PATH}" \
  --type "String" \
  --value "$${SERVER_PUB}" \
  --overwrite \
  --region "$${AWS_REGION}"

# Determine primary interface (usually eth0) and its CIDR
PRIMARY_IF=$(ip -o -4 route show to default | awk '{print $5}')
# Setup nat from WG -> primary IF
cat >/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $${WG_CIDR_HOST}
ListenPort = $${WG_PORT}
PrivateKey = $${SERVER_PRIV}
# NAT: allow WG clients to reach VPC subnets and the internet (if you choose)
PostUp   = iptables -t nat -A POSTROUTING -s $${WG_CIDR} -o $${PRIMARY_IF} -j MASQUERADE
PostUp   = iptables -A FORWARD -i $${PRIMARY_IF} -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
PostUp   = iptables -A FORWARD -i wg0 -o $${PRIMARY_IF} -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s $${WG_CIDR} -o $${PRIMARY_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i $${PRIMARY_IF} -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -o $${PRIMARY_IF} -j ACCEPT
EOF

# Add HOME peer (required)
cat >>/etc/wireguard/wg0.conf <<EOF
[Peer]
# Home gateway/NAS peer
PublicKey = $${HOME_PUB}
# AllowedIPs list controls what the HOME side can send through the tunnel
AllowedIPs = $${HOME_LAN}, $${WG_CIDR}
PersistentKeepalive = 25
EOF

# Optional laptop peer (can access HOME LAN and the VPC)
if [ -n "$${LAPTOP_PUB}" ]; then
cat >>/etc/wireguard/wg0.conf <<EOF
[Peer]
# Laptop peer
PublicKey = $${LAPTOP_PUB}
AllowedIPs = $${WG_CIDR}, $${HOME_LAN}, $${PRIVATE_SUBNET}
PersistentKeepalive = 25
EOF
fi

# Enable & start WireGuard
systemctl enable --now wg-quick@wg0

# Sanity logs
wg show
