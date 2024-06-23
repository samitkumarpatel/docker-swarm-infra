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

provider "aws" {
  region = "eu-north-1"
}

resource "tls_private_key" "foo" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "foo" {
  key_name   = "id_rsa"
  public_key = tls_private_key.foo.public_key_openssh
}

# Local copy of key_pair
resource "local_file" "key" {
  content  = tls_private_key.foo.private_key_pem
  filename = "${aws_key_pair.foo.key_name}.pem"
}

resource "null_resource" "set_readonly" {
  provisioner "local-exec" {
    command = "chmod 400 ${local_file.key.filename}"
  }

  triggers = {
    key_file = local_file.key.filename
  }
}

resource "aws_security_group" "manager_sg" {
  name = "manager_sg"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "worker_sg" {
  name = "worker_sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.manager.public_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "manager" {
  ami           = "ami-0014ce3e52359afbd"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.manager_sg.name]
  key_name = aws_key_pair.foo.key_name

  tags = {
    Name = "Manager"
  }
}

resource "aws_instance" "worker" {
  count         = 2
  ami           = "ami-0014ce3e52359afbd"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.worker_sg.name]
  key_name = aws_key_pair.foo.key_name

  tags = {
    Name = "Worker-${count.index + 1}"
  }
}

output "manager_public_ip" {
  value = aws_instance.manager.public_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

# ansible ansible-inventory -i ansible/inventory.yml --list (show the inventory) 
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
  count  = 2
  name   = aws_instance.worker[count.index].public_ip
  groups = ["worker"]
  variables = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = "id_rsa.pem"
    ansible_connection           = "ssh"
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no"
  }
}