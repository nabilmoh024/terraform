# Root-level variables for this stack. They are DECLARED here, ASSIGNED in
# terraform.tfvars, and PASSED to the module in main.tf.

variable "aws_region" {
  description = "AWS region to deploy into; must match the region of the vpc stack"
  type        = string
  nullable    = false
}

variable "project" {
  description = "Project name used as the first part of every resource name"
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Environment name: dev, staging or prod. Also selects which vpc state file is read."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the application server"
  type        = string
  nullable    = false
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  nullable    = false
}

variable "ingress_rules" {
  description = "Inbound security group rules keyed by a short stable name; leave empty for none"
  type = map(object({
    description = optional(string)
    from_port   = number
    to_port     = number
    ip_protocol = optional(string, "tcp")
    cidr_ipv4   = string
  }))
  default  = {}
  nullable = false
}
