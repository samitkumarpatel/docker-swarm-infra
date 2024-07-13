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
  backend "s3" {
    bucket = "tfpocbucket001"
    key    = "docker-swarm/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = local.region
}

locals {
  region        = "eu-north-1"
  workers_count = 2
  tags = {
    infra = "docker-swarm"
  }
}

# default VPC
data "aws_vpc" "default" {
  default = true
}

# default SUBNET
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "public" {
  id = data.aws_subnets.default.ids[0]
}

data "aws_subnet" "private" {
  id = data.aws_subnets.default.ids[1]
}

# NAT Gateway
resource "aws_eip" "private" {
  domain = "vpc"
}

resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.private.id
  subnet_id     = data.aws_subnet.public.id

  tags = local.tags
}

# Route Table
resource "aws_route_table" "private" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.private.id
  }

  tags = merge(local.tags, { Name = "private" })
}

resource "aws_route_table_association" "private" {
  subnet_id      = data.aws_subnet.private.id
  route_table_id = aws_route_table.private.id
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

# Security Group
resource "aws_security_group" "manager_sg" {
  name   = "manager_sg"
  vpc_id = data.aws_vpc.default.id

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

  ingress {
    from_port   = 2375
    to_port     = 2375
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
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [data.aws_subnet.public.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_network_interface" "public_ni" {

  subnet_id       = data.aws_subnet.public.id
  security_groups = [aws_security_group.manager_sg.id]

  tags = local.tags
}

# ec2
resource "aws_instance" "manager" {
  ami                         = "ami-0014ce3e52359afbd"
  instance_type               = "t3.micro"

  network_interface {
    network_interface_id = aws_network_interface.public_ni.id
    device_index         = 0
  }

  key_name                    = aws_key_pair.foo.key_name
 
  credit_specification {
    cpu_credits = "unlimited"
  }

  tags = merge(local.tags, { Name = "Manager" })
}


resource "aws_network_interface" "private_ni" {

  count                       = local.workers_count

  subnet_id       = data.aws_subnet.private.id
  security_groups = [aws_security_group.worker_sg.id]

  tags = local.tags
}

resource "aws_instance" "worker" {
  count                       = local.workers_count
  ami                         = "ami-0014ce3e52359afbd"
  instance_type               = "t3.micro"
  key_name                    = aws_key_pair.foo.key_name
  #associate_public_ip_address = false

  network_interface {
    network_interface_id = aws_network_interface.private_ni[count.index].id
    device_index         = 0
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

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

# EFS
resource "aws_efs_file_system" "foo" {
  creation_token   = "all-in-one-example"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = local.tags
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "ec2 talk to efs"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # ec2-sg
    security_groups = [aws_security_group.manager_sg.id, aws_security_group.worker_sg.id]
  }

  tags = local.tags
}

resource "aws_efs_mount_target" "foo" {
  count           = length(data.aws_subnets.default.ids)
  file_system_id  = aws_efs_file_system.foo.id
  subnet_id       = element(data.aws_subnets.default.ids, count.index)
  security_groups = [aws_security_group.efs_sg.id]
}

# Db
resource "aws_db_subnet_group" "db" {
  name       = "db-subnet-groups"
  subnet_ids = data.aws_subnets.default.ids
  tags       = local.tags
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Allow ec2-sg will talk to this db"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # ec2-sg's
    security_groups = [aws_security_group.manager_sg.id, aws_security_group.worker_sg.id]
  }

  tags = local.tags
}

resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "db" {
  allocated_storage      = 10
  db_name                = "postgres"
  engine                 = "postgres"
  engine_version         = "16.2"
  instance_class         = "db.t3.micro"
  username               = "postgres"
  password               = random_password.db.result
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]

  tags = local.tags
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
    mount_path                   = "/home/ubuntu/efs"
    efs_endpoint                 = "${aws_efs_file_system.foo.dns_name}:/"
    db_endpoint                  = aws_db_instance.db.endpoint
    db_name                      = aws_db_instance.db.db_name
    db_username                  = aws_db_instance.db.username
    db_password                  = aws_db_instance.db.password
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
    mount_path                   = "/home/ubuntu/efs"
    efs_endpoint                 = "${aws_efs_file_system.foo.dns_name}:/"
    db_endpoint                  = aws_db_instance.db.endpoint
    db_name                      = aws_db_instance.db.db_name
    db_username                  = aws_db_instance.db.username
    db_password                  = aws_db_instance.db.password
  }
}
