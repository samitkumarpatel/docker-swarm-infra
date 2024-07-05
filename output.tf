output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "worker_public_ips" {
  value = aws_instance.worker[*].public_ip
}

output "efs_hostname" {
  value = aws_efs_file_system.foo.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.endpoint
}