output "cp_main_ip" {
  description = "Public ip of the main cp to connect"
  value       = aws_instance.cp_main.public_ip
}

output "worker_ips" {
  description = "Public ips of the worker nodes"
  value       = aws_instance.worker[*].public_ip
}
