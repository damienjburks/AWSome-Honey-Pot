terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
}

# Network Dependencies
resource "aws_vpc" "honeypot_vpc" {
    cidr_block = "192.168.1.0/24"
}

resource "aws_subnet" "hp_instance_subnet" {
  vpc_id            = aws_vpc.honeypot_vpc.id
  cidr_block        = "192.168.1.0/27"
  availability_zone = "us-east-1a"

  tags = {
    Name = "hp_instance_subnet"
  }
}

resource "aws_security_group" "default_hp_sg" {
  name        = "hp_sg"
  description = "Default HP SG for instance"
  vpc_id      = aws_vpc.honeypot_vpc.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.honeypot_vpc.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.honeypot_vpc.ipv6_cidr_block]
  }

  tags = {
    Name = "honeypot_security_group"
  }
}

resource "aws_network_interface" "nw_int" {
  subnet_id   = aws_subnet.hp_instance_subnet.id
  private_ips = ["192.168.1.4"]

  tags = {
    Name = "primary_network_interface"
  }
}

# Main HoneyPot Instance
resource "aws_instance" "honeypot_instance" {
  ami           = "ami-06e9b30b57b32ec3a"
  instance_type = "t2.Xlarge"
  subnet_id = aws_subnet.hp_instance_subnet.id
  
  network_interface {
    network_interface_id = aws_network_interface.nw_int.id
    device_index = 0
  }

  security_groups = [aws_security_group.default_hp_sg.id]

  ebs_block_device = {
    volume_type = "gp2"
    volume_size = "128"
    delete_on_termination = true
  }

  tags = {
    Name = "HoneyPot Management Instance"
  }
}

# Instance Key Pair Generation
resource "aws_key_pair" "tf-key-pair" {
    key_name = "tf-key-pair"
    public_key = tls_private_key.rsa.public_key_openssh
}
resource "tls_private_key" "rsa" {
    algorithm = "RSA"
    rsa_bits  = 4096
}
resource "local_file" "tf-key" {
    content  = tls_private_key.rsa.private_key_pem
    filename = "honeypot-instance-key"
}
