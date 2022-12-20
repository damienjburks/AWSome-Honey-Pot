provider "aws" {
  region = "us-east-1"
}

# Network Dependencies
resource "aws_vpc" "honeypot_vpc" {
  cidr_block           = "192.168.1.0/24"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "TPOT_VPC"
  }
}

resource "aws_internet_gateway" "tpot_vpc_igw" {
  vpc_id = aws_vpc.honeypot_vpc.id
  tags = {
    Name = "TPOT_VPC_IGW"
  }
}

resource "aws_route_table" "tpot_route_table" {
  vpc_id = aws_vpc.honeypot_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tpot_vpc_igw.id
  }
  tags = {
    Name = "TPOT Default Route Table"
  }
}

resource "aws_route_table_association" "tpot_rt_association" {
  subnet_id      = aws_subnet.hp_instance_subnet.id
  route_table_id = aws_route_table.tpot_route_table.id
}


resource "aws_subnet" "hp_instance_subnet" {
  vpc_id            = aws_vpc.honeypot_vpc.id
  cidr_block        = "192.168.1.0/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "hp_instance_subnet"
  }
}

resource "aws_security_group" "tpot_security_group" {
  name        = "T-Pot SG"
  description = "T-Pot Honeypot SG"
  vpc_id      = aws_vpc.honeypot_vpc.id

  ingress { # AWS System Logs Debugging
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 64000
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 64294
    to_port     = 64294
    protocol    = "tcp"
    cidr_blocks = ["your_ip_addr_cidr"] # Change your IP address here
  }
  ingress {
    from_port   = 64295
    to_port     = 64295
    protocol    = "tcp"
    cidr_blocks = ["your_ip_addr_cidr"] # Change to your IP address here
  }
  ingress {
    from_port   = 64297
    to_port     = 64297
    protocol    = "tcp"
    cidr_blocks = ["your_ip_addr_cidr"] # Change to your IP address here
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "T-Pot SG"
  }
}

resource "aws_eip" "tpot_instance_eip" {
  instance = aws_instance.tpot_instance.id
  vpc      = true
}

# Main HoneyPot Instance
resource "aws_instance" "tpot_instance" {
  ami           = "ami-0a6cdd2c74bcdc701"
  instance_type = "t2.large"
  subnet_id     = aws_subnet.hp_instance_subnet.id
  key_name      = aws_key_pair.tf_key_pair.key_name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 128
    delete_on_termination = true
  }

  vpc_security_group_ids      = [aws_security_group.tpot_security_group.id]
  associate_public_ip_address = true

  tags = {
    Name = "T-Pot Honeypot Instance"
  }
}

# Instance Key Pair Generation
resource "aws_key_pair" "tf_key_pair" {
  key_name   = "hp_key_pair"
  public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "tf_key" {
  content  = tls_private_key.rsa.private_key_openssh
  filename = "hp_key_pair.pem"
}
