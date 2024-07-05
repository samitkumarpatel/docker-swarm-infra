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