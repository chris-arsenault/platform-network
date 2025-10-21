output "instance_id" {
  value = aws_instance.this.id
}

output "private_ip" {
  value = aws_instance.this.private_ip
}

output "primary_network_interface_id" {
  value = aws_network_interface.this.id
}

output "public_ip" {
  value = var.associate_eip ? aws_eip.this[0].public_ip : ""
}

output "network_interface_id" {
  value = aws_network_interface.this.id
}
