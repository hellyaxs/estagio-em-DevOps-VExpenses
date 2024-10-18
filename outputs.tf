output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereços IP públicos das instâncias EC2"
  value       = [aws_instance.debian_ec2[*].public_ip]
}
