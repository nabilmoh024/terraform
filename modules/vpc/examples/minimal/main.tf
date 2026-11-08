# Try the vpc module on its own, with no environments and no remote state:
#   terraform init && terraform apply
#   terraform destroy      <- when you are done
# NAT is off, so this example creates no billable gateway while it exists.
provider "aws" {
  region = "ap-south-1"
}

module "vpc" {
  source = "../.."

  name               = "vpc-example"
  vpc_cidr_block     = "10.20.0.0/16"
  availability_zones = ["ap-south-1a", "ap-south-1b"]
  enable_nat_gateway = false
}

output "vpc_id" {
  description = "ID of the example VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs of the example VPC"
  value       = module.vpc.private_subnet_ids
}
