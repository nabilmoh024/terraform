# Partial backend configuration. Backend blocks cannot use variables, so the settings
# shared by every dev stack (bucket, region) live in ../backend.hcl and are supplied at
# init time:
#
#   terraform init -backend-config=../backend.hcl
#
# Only what is unique to THIS stack stays here. The key is what keeps the vpc and ec2
# states apart, so scripts/check-env-parity.sh verifies it matches <environment>/<stack>.
terraform {
  backend "s3" {
    key          = "prod/vpc/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # native S3 locking, Terraform 1.10+, no DynamoDB table needed
  }
}
