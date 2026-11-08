output "state_bucket_names" {
  description = "State bucket name per environment. Put these in each stack's backend.tf and (for ec2) terraform.tfvars."
  value       = { for environment, bucket in aws_s3_bucket.state : environment => bucket.id }
}

output "aws_region" {
  description = "Region the buckets live in; use it as region in every backend.tf"
  value       = var.aws_region
}
