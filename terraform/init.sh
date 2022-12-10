#!/bin/bash

# Install packages
sudo apt-get update > /dev/null
sudo apt-get install -y fail2ban nginx
sudo snap install core
sudo snap refresh core
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot

# Write nginx.conf
cat <<EOF | sudo tee -a /etc/nginx/conf.d/${SERVER}.conf
upstream tunnel {
  server 127.0.0.1:8888;
}

server {
  server_name ${SERVER};

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
  if (\$host = grok.otherthings.net) {
      return 301 https://\$host\$request_uri;
  }

  server_name ${SERVER};
  listen 80;
  return 404;
}
EOF

# Run nginx
sudo systemctl start nginx.service

# Run certbot
sudo certbot --nginx --non-interactive --agree-tos -d ${SERVER} -m ${EMAIL}
