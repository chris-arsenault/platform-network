dnf -y install nginx

rm -f /etc/nginx/conf.d/default.conf

cat >/etc/nginx/conf.d/reverse-proxy.conf <<'EOF'
%{ for host, route in ROUTES ~}
server {
  listen 80;
  server_name ${host};

  location / {
    proxy_pass http://${route.address}:${route.port};
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Connection "";
  }

  access_log /var/log/nginx/${host}_access.log;
  error_log  /var/log/nginx/${host}_error.log warn;
}
%{ endfor }
EOF

systemctl enable --now nginx
