#!/bin/bash

# Install packages
sudo apt-get update > /dev/null
sudo apt-get install -y fail2ban nginx

# Write nginx.conf
cat <<EOF | sudo tee -a /etc/nginx/conf.d/${DOMAIN}.conf
upstream tunnel {
  server 127.0.0.1:8888;
}

server {
  server_name *.${DOMAIN};

  listen 443 ssl;
  ssl_certificate /etc/ssl/certs/tunnel_cert.pem;
  ssl_certificate_key /etc/ssl/certs/tunnel_key.pem;

  location / {
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header Host \$http_host;
    proxy_redirect off;

    proxy_pass http://tunnel;
  }
}

server {
  server_name *.${DOMAIN};

  listen 80;

  return 301 https://\$host\$request_uri;
}
EOF

# Run nginx
sudo systemctl start nginx.service
sudo systemctl enable nginx.service
sudo systemctl restart nginx.service
