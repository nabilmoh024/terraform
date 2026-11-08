output "instance_id" {
  description = "ID of the EC2 instance; use it with: aws ssm start-session --target <id>"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address of the instance inside the VPC"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "ID of the instance security group. Other stacks (for example rds) allow inbound traffic from this group."
  value       = aws_security_group.this.id
}

output "ami_id" {
  description = "AMI the instance was launched from"
  value       = local.ami_id
}

output "iam_role_name" {
  description = "Name of the SSM instance role, or null when enable_ssm is false. Attach extra policies here."
  value       = one(aws_iam_role.this[*].name)
}
