[Unit]
Description=Vector observability pipeline
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/env vector --config /etc/vector/vector.toml
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
