

output "securitygroup_id" {
  description = "Security Group ID"
  value       = aws_security_group.mongo[0].id
}