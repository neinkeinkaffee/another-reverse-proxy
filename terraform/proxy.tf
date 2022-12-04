resource "aws_key_pair" "proxy_key_pair" {
  key_name   = "twmac"
  public_key = file(var.keyfile)
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
  key_name                    = aws_key_pair.proxy_key_pair.key_name
  user_data                   = data.template_file.init.rendered
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.proxy_sg.id]
  tags = {
    Name = "proxy"
  }
}

data "template_file" "init" {
  template = file("init.sh")

  vars = {
    CLOUDFLARE_API_TOKEN = var.cloudflare_api_token
    EMAIL = var.email
    SERVER = "${var.subdomain}.${var.domain}"
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

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.http.ip.body}/32"]
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
  name    = var.subdomain
  value   = aws_eip.proxy_eip.public_ip
  type    = "A"
#  proxied = true
}

output "proxy_eip" {
  value = aws_eip.proxy_eip.public_ip
}
