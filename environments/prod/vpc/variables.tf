# Root-level variables for this stack. They are DECLARED here, ASSIGNED in
# terraform.tfvars, and PASSED to the module in main.tf.

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  nullable    = false
}

variable "project" {
  description = "Project name used as the first part of every resource name"
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Environment name: dev, staging or prod"
  type        = string
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr_block" {
  description = "IPv4 CIDR block for the VPC; keep it unique per environment if you ever plan to peer them"
  type        = string
  nullable    = false
}

variable "availability_zones" {
  description = "Availability zones to spread subnets across"
  type        = list(string)
  nullable    = false
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) for private subnet internet access"
  type        = bool
  nullable    = false
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway (cheap) instead of one per zone (resilient)"
  type        = bool
  nullable    = false
}
