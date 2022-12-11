resource "aws_key_pair" "proxy_key_pair_pi" {
  key_name   = "pi"
  public_key = file(var.keyfile_pi)
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = aws_subnet.public_subnet.id
  key_name                    = aws_key_pair.proxy_key_pair_pi.key_name
  user_data                   = data.template_cloudinit_config.init.rendered
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.proxy_sg.id]
  tags = {
    Name = "proxy"
  }
}

data "template_cloudinit_config" "init" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #!/bin/bash
    echo "${cloudflare_origin_ca_certificate.cloudflare_to_proxy.certificate}" | sudo tee -a /etc/ssl/certs/tunnel_cert.pem
    echo "${tls_private_key.cloudflare_to_proxy.private_key_pem}" | sudo tee -a /etc/ssl/certs/tunnel_key.pem
    EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.init.rendered
  }
}

data "template_file" "init" {
  template = file("init.sh")

  vars = {
    EMAIL = var.email
    DOMAIN = var.domain
  }
}

resource "aws_eip" "proxy_eip" {
  instance   = aws_instance.proxy.id
  vpc        = true
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "proxy"
  }
}

data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

resource "aws_security_group" "proxy_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = tolist(setunion(var.ssh_allow_list, [data.http.ip.body]))
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["${ingress.value}/32"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security-group-proxy"
  }
}

resource "cloudflare_record" "tunnel" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  value   = aws_eip.proxy_eip.public_ip
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "unproxied" {
  zone_id = var.cloudflare_zone_id
  name    = "host"
  value   = aws_eip.proxy_eip.public_ip
  type    = "A"
}

resource "tls_private_key" "cloudflare_to_proxy" {
  algorithm = "RSA"
}

resource "tls_cert_request" "cloudflare_to_proxy" {
  private_key_pem = tls_private_key.cloudflare_to_proxy.private_key_pem

  subject {
    common_name  = var.domain
  }
}

provider "cloudflare" {
  alias = "origin_ca"
  api_user_service_key = var.cloudflare_origin_ca_key
}

resource "cloudflare_origin_ca_certificate" "cloudflare_to_proxy" {
  provider = cloudflare.origin_ca
  csr                = tls_cert_request.cloudflare_to_proxy.cert_request_pem
  hostnames          = ["*.${var.domain}"]
  request_type       = "origin-rsa"
  requested_validity = 7
}

output "proxy_eip" {
  value = aws_eip.proxy_eip.public_ip
}
