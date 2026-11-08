# Step 1 of the flow: the VALUES for this environment. Terraform loads this file
# automatically from the working directory. Non-secret values only.
aws_region         = "ap-south-1"
project            = "practice"
environment        = "prod"
vpc_cidr_block     = "10.1.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
enable_nat_gateway = true
single_nat_gateway = false # one NAT gateway per zone, so losing a zone does not cut off the others
