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

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

# ansible ansible-inventory -i inventory.yml --list (show the inventory)
resource "ansible_host" "master" {
  name   = aws_instance.master.public_ip
  groups = ["master"]
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
  count  = 2
  name   = aws_instance.worker[count.index].public_ip
  groups = ["worker"]
  variables = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = "id_rsa.pem"
    ansible_connection           = "ssh"
    ansible_ssh_common_args      = "-o StrictHostKeyChecking=no -o ProxyCommand='ssh -W %h:%p -q ubuntu@${aws_instance.master.public_ip} -i id_rsa.pem'"
    mount_path                   = "/home/ubuntu/efs"
    efs_endpoint                 = "${aws_efs_file_system.foo.dns_name}:/"
    db_endpoint                  = aws_db_instance.db.endpoint
    db_name                      = aws_db_instance.db.db_name
    db_username                  = aws_db_instance.db.username
    db_password                  = aws_db_instance.db.password
  }
}