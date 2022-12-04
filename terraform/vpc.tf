resource "aws_vpc" "vpc" {
  cidr_block = "10.0.1.0/24"
  enable_dns_hostnames = true
  tags = {
    Name = "vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "${var.region}a"
  cidr_block        = "10.0.1.0/24"
  tags = {
    Name = "subnet-public"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }
  tags = {
    Name = "route-table-public"
  }
}

resource "aws_route_table_association" "route_subnet" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
}
