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

resource "aws_security_group" "efs" {
  name        = "efs-sg"
  description = "Allow ec2-sg will talk to this efs"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # master-sg
    security_groups = [aws_security_group.master_sg.id, aws_security_group.worker_sg.id]
  }

  tags = local.tags
}

resource "aws_efs_mount_target" "foo" {
  file_system_id  = aws_efs_file_system.foo.id
  subnet_id       = aws_default_subnet.default_az1.id
  security_groups = [aws_security_group.efs.id]
}

# Db

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Allow ec2-sg will talk to this db"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # ec2-sg
    security_groups = [aws_security_group.master_sg.id, aws_security_group.worker_sg.id]
  }

  tags = local.tags
}

resource "random_password" "password" {
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
  password               = random_password.password.result
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.foo.name
  vpc_security_group_ids = [aws_security_group.db.id]

  tags = local.tags
}
