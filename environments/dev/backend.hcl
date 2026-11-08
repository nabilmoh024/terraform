# Backend settings shared by every dev stack. Used as:
#   terraform init -backend-config=../backend.hcl
# Replace ACCOUNT_ID with your AWS account ID (README step 2). The bucket itself is
# created by bootstrap/state-backend, which uses the same naming rule.
bucket = "tf-state-dev-389083921445"
region = "ap-south-1"
