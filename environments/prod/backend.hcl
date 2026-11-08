# Backend settings shared by every prod stack. Used as:
#   terraform init -backend-config=../backend.hcl
# Replace ACCOUNT_ID with your AWS account ID (README step 2). The bucket itself is
# created by bootstrap/state-backend, which uses the same naming rule.
bucket = "tf-state-prod-ACCOUNT_ID"
region = "ap-south-1"
