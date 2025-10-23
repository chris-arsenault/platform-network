#!/bin/bash
set -euxo pipefail

dnf -y upgrade --refresh

cat >/usr/local/bin/apply-system-hardening.sh <<'EOF'
${HARDENING_SCRIPT}
EOF

chmod 700 /usr/local/bin/apply-system-hardening.sh
/usr/local/bin/apply-system-hardening.sh

systemctl disable --now amazon-cloudwatch-agent.service || true

cat >/etc/yum.repos.d/vector.repo <<'EOF'
${VECTOR_REPO_CONFIG}
EOF

dnf -y install vector

TOKEN="$(curl -sS -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')"
INSTANCE_ID="$(curl -sS -H "X-aws-ec2-metadata-token: $${TOKEN}" http://169.254.169.254/latest/meta-data/instance-id)"
AWS_REGION="$(curl -sS -H "X-aws-ec2-metadata-token: $${TOKEN}" http://169.254.169.254/latest/meta-data/placement/region)"

mkdir -p /etc/vector

cat >/etc/vector/environment <<EOF
INSTANCE_ID=$${INSTANCE_ID}
AWS_REGION=$${AWS_REGION}
EOF

cat >/etc/vector/vector.toml <<'EOF'
${VECTOR_CONFIG}
EOF

mkdir -p /etc/systemd/system/vector.service.d

cat >/etc/systemd/system/vector.service.d/override.conf <<'EOF'
${VECTOR_SERVICE_OVERRIDE}
EOF

systemctl daemon-reload

systemctl enable --now vector

${EXTRA_SNIPPET}
