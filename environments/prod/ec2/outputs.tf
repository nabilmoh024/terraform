# Contract with downstream stacks (rds will read security_group_id to allow the app in).

output "instance_id" {
  description = "ID of the EC2 instance; connect with: aws ssm start-session --target <id>"
  value       = module.app.instance_id
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = module.app.private_ip
}

output "security_group_id" {
  description = "ID of the instance security group"
  value       = module.app.security_group_id
}
