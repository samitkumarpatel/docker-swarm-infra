terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.41"
    }

    ansible = {
      version = "~> 1.3.0"
      source  = "ansible/ansible"
    }
  }
}

locals {
  region        = "eu-north-1"
  workers_count = 2
  tags = {
    infra = "docker-swarm"
  }
}

provider "aws" {
  region = local.region
}

# VPC
data "aws_vpc" "default_vpc" {}

# SUBNET
data "aws_subnet" "default_subnet_public" {
  availability_zone = "${local.region}a"
}

data "aws_subnet" "default_subnet_private" {
  availability_zone = "${local.region}b"
}

# RSA KEY PAIR
resource "tls_private_key" "foo" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "foo" {
  key_name   = "id_rsa"
  public_key = tls_private_key.foo.public_key_openssh
}

output "ssh_key" {
  value     = tls_private_key.foo.private_key_pem
  sensitive = true
}

resource "aws_security_group" "manager_sg" {
  name   = "manager_sg"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
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
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "worker_sg" {
  name   = "worker_sg"
  vpc_id = data.aws_vpc.default_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    #security_groups = [aws_security_group.manager_sg.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_instance" "manager" {
  ami                         = "ami-0014ce3e52359afbd"
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.manager_sg.name]
  key_name                    = aws_key_pair.foo.key_name
  subnet_id                   = data.aws_subnet.default_subnet_public.id
  associate_public_ip_address = true

  tags = merge(local.tags, { Name = "Manager" })
}

resource "aws_instance" "worker" {
  count                       = local.workers_count
  ami                         = "ami-0014ce3e52359afbd"
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.worker_sg.name]
  key_name                    = aws_key_pair.foo.key_name
  subnet_id                   = data.aws_subnet.default_subnet_private.id
  associate_public_ip_address = false

  tags = merge(local.tags, { Name = "Worker" })
}

locals {
  worker_ips = [for instance in aws_instance.worker : instance.private_ip]
}

output "worker_private_ips" {
  value = [for instance in aws_instance.worker : instance.private_ip]
}

output "manager_ip" {
  value = aws_instance.manager.public_ip
}

# ansible ansible-inventory -i inventory.yml --list (show the inventory)
resource "ansible_host" "manager" {
  name   = aws_instance.manager.public_ip
  groups = ["manager"]
  variables = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = "id_rsa.pem"
    ansible_connection           = "ssh"
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}

resource "ansible_host" "worker" {
  count  = local.workers_count
  name   = local.worker_ips[count.index]
  groups = ["worker"]
  variables = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = "id_rsa.pem"
    ansible_connection           = "ssh"
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no -o ProxyCommand='ssh -W %h:%p -q ubuntu@${aws_instance.manager.public_ip} -i id_rsa.pem'"
  }
}
