output "cp_main_ip" {
  description = "Public ip of the main cp to connect"
  value       = aws_instance.cp_main.public_ip
}
