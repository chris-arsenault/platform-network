#!/bin/bash
set -euxo pipefail

dnf -y upgrade --refresh

cat >/usr/local/bin/apply-system-hardening.sh <<'EOF'
#!/bin/bash
set -euxo pipefail

dnf -y install dnf-automatic chrony audit aide scap-security-guide

systemctl enable --now chronyd
systemctl enable --now auditd

cat >/etc/dnf/automatic.conf <<'EOC'
[commands]
upgrade_type = security
download_updates = yes
apply_updates = yes

[emitters]
emit_via = motd

[base]
debuglevel = 1
EOC

systemctl enable --now dnf-automatic-install.timer

cat >/etc/profile.d/00-secure-umask.sh <<'EOC'
umask 027
EOC

cat >/etc/sysctl.d/90-hardening.conf <<'EOC'
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
kernel.kptr_restrict = 1
kernel.randomize_va_space = 2
EOC

sysctl --system

if grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
else
  echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
fi

if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
else
  echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
fi

systemctl try-restart sshd || true

mkdir -p /etc/aide.conf.d

cat >/etc/aide.conf.d/amazon-linux.conf <<'EOC'
database_out=file:/var/lib/aide/aide.db.gz
database_new=file:/var/lib/aide/aide.db.new.gz
gzip_dbout=yes
report_url=stdout
EOC

if [ ! -f /var/lib/aide/aide.db.gz ]; then
  aide --init
  mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
fi

if [ -f /usr/share/xml/scap/ssg/content/ssg-amazon_linux-2023-ds.xml ]; then
  oscap xccdf eval \
    --profile xccdf_org.ssgproject.content_profile_stig \
    --report /var/log/oscap-stig.html \
    --results /var/log/oscap-stig.xml \
    --fetch-remote-resources \
    /usr/share/xml/scap/ssg/content/ssg-amazon_linux-2023-ds.xml || true
fi
EOF

chmod 700 /usr/local/bin/apply-system-hardening.sh
/usr/local/bin/apply-system-hardening.sh

dnf -y install amazon-cloudwatch-agent

cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<JSON
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/var/log/amazon-cloudwatch-agent.log",
    "omit_hostname": true
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": ${FILE_LOGS_JSON}
      },
      "journals": {
        "collect_list": ${JOURNAL_LOGS_JSON}
      }
    },
    "log_stream_name": "{instance_id}"
  }
}
JSON

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop || true
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

${EXTRA_SNIPPET}
