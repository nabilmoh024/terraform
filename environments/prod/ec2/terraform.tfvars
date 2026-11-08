# Step 1 of the flow: the VALUES for this environment. Terraform loads this file
# automatically from the working directory. Non-secret values only.
aws_region       = "ap-south-1"
project          = "practice"
environment      = "prod"
instance_type    = "t3.small"
root_volume_size = 30
