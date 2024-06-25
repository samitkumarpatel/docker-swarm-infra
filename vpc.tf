#VPC
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

# SUBNET
resource "aws_default_subnet" "default_az1" {
  availability_zone = "eu-north-1a"

  tags = {
    Name = "Default subnet for eu-north-1a"
  }
}
resource "aws_default_subnet" "default_az1b" {
  availability_zone = "eu-north-1b"

  tags = {
    Name = "Default subnet for eu-north-1b"
  }
}

resource "aws_db_subnet_group" "foo" {
  name       = "db-subnet-groups"
  subnet_ids = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az1b.id]
  tags       = local.tags
}