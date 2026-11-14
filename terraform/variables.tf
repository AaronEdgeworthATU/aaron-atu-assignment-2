# -----------------------------------------------------------------------------
# variables.tf
# Inputs to the configuration. "validation" blocks give an early, local check,
# but they can be edited by whoever edits this code. Sentinel policies are the
# central, organisation-level guardrail that developers cannot simply remove.
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy into. Must be an approved sovereign region."
  type        = string
  default     = "eu-west-1" # Dublin, Ireland

  # Fails `terraform plan` immediately if someone passes e.g. "us-east-1".
  validation {
    condition     = contains(["eu-west-1"], var.aws_region)
    error_message = "Only eu-west-1 (Ireland) is approved for data residency."
  }
}

variable "organisation" {
  description = "Organisation identifier, applied as a tag."
  type        = string
  default     = "L00205292"
}

variable "environment" {
  description = "Deployment environment name (dev, test, prod)."
  type        = string
  default     = "dev"
}

variable "data_classification" {
  description = "Sensitivity of data handled by these resources."
  type        = string
  default     = "sensitive"
}

variable "instance_type" {
  description = "EC2 instance size. Must be on the approved list."
  type        = string
  default     = "t3.micro" # small and cheap; free-tier eligible in many accounts
}

variable "ami_id" {
  description = "AMI (machine image) ID for the EC2 instance."
  type        = string
  # Placeholder: plan does not check that an AMI exists, so any well-formed ID
  # works for plan-only testing. Use a real eu-west-1 AMI ID if you ever apply.
  default = "ami-0123456789abcdef0"
}

variable "vpc_cidr" {
  description = "IP address range for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

# Each subnet takes a separate /24 (256 addresses) inside the VPC's /16.
variable "public_subnet_cidr" {
  description = "IP range for the public subnet (internet-facing, e.g. load balancer)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "app_subnet_cidr" {
  description = "IP range for the private app subnet (web server)."
  type        = string
  default     = "10.0.2.0/24"
}

variable "data_subnet_cidr" {
  description = "IP range for the private data subnet (future database)."
  type        = string
  default     = "10.0.3.0/24"
}

variable "admin_ssh_cidr" {
  description = "The ONLY network allowed to SSH in, e.g. an office or VPN range."
  type        = string
  # 203.0.113.0/24 is a reserved documentation range: a safe placeholder.
  # Never 0.0.0.0/0, which would mean "the entire internet".
  default = "203.0.113.0/24"
}
