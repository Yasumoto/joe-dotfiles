output "bouncer_ip_address" {
  description = "List of public IP addresses assigned to this instance."
  value       = aws_instance.bouncer.*.public_ip
}
