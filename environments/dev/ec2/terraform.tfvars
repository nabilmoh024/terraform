# Step 1 of the flow: the VALUES for this environment. Terraform loads this file
# automatically from the working directory. Non-secret values only.
aws_region       = "ap-south-1"
project          = "practice"
environment      = "dev"
instance_type    = "t3.micro"
root_volume_size = 20

# Practice exercise: allow HTTP from inside the VPC only, then re-run plan and apply.
# ingress_rules = {
#   http_from_vpc = {
#     from_port = 80
#     to_port   = 80
#     cidr_ipv4 = "10.0.0.0/16"
#   }
# }
