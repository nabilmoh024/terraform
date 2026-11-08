# Step 1 of the flow: the VALUES for this environment. Terraform loads this file
# automatically from the working directory. Non-secret values only.
aws_region         = "ap-south-1"
project            = "practice"
environment        = "dev"
vpc_cidr_block     = "10.0.0.0/16"
availability_zones = ["ap-south-1a", "ap-south-1b"]
enable_nat_gateway = true
single_nat_gateway = true # one shared NAT keeps the practice bill low
