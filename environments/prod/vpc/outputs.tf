# These outputs are the contract with downstream stacks (ec2, later rds), which read
# them through terraform_remote_state. Do not rename or remove one without updating
# every consumer first.

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered like availability_zones"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered like availability_zones"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways keyed by availability zone"
  value       = module.vpc.nat_gateway_public_ips
}
