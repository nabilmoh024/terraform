variable "aws_region" {
  description = "AWS region that holds the state buckets; use the same region in every backend.tf"
  type        = string
  default     = "ap-south-1"
  nullable    = false
}

variable "environments" {
  description = "One state bucket is created per environment, named tf-state-<environment>-<account id>"
  type        = set(string)
  default     = ["dev", "prod"]
  nullable    = false
}

variable "tags" {
  description = "Extra tags applied to every state bucket"
  type        = map(string)
  default     = {}
  nullable    = false
}
