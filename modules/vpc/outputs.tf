output "vpc_id" {
  description = "ID of the VPC. Consumed by the ec2 (and later rds) stacks."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC, useful for security group rules that allow traffic from inside the VPC"
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability zones used, in the same order as the subnet ID lists"
  value       = var.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered like availability_zones. Use for load balancers and NAT gateways."
  value       = [for zone in var.availability_zones : aws_subnet.public[zone].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered like availability_zones. Use for EC2, RDS and other workloads."
  value       = [for zone in var.availability_zones : aws_subnet.private[zone].id]
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways keyed by availability zone; give these to third parties that allow-list your outbound traffic"
  value       = { for zone, address in aws_eip.nat : zone => address.public_ip }
}
