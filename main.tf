locals {
  
  tags = {
    Name = "swarm-infra"
  }
}

resource "tls_private_key" "foo" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "foo" {
  key_name   = "id_rsa"
  public_key = tls_private_key.foo.public_key_openssh
}

output "ssh_key" {
  value = tls_private_key.foo.private_key_pem
  sensitive = true
}

resource "aws_security_group" "master_sg" {
  name = "master_sg"

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
}

resource "aws_security_group" "worker_sg" {
  name = "worker_sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.master.public_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "master" {
  ami           = "ami-0014ce3e52359afbd"
  instance_type = "t3.micro"
  security_groups = [aws_security_group.master_sg.name]
  key_name = aws_key_pair.foo.key_name

  tags = {
    Name = "Master"
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