variable "aws_region" {
  description = "AWS Region selected for the CloudWeave learning environment."
  type        = string
  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region must not be empty."
  }
}

variable "aws_profile" {
  description = "Optional shared AWS configuration profile. Leave null to use the standard AWS credential chain."
  type        = string
  default     = null
  nullable    = true
}

variable "availability_zone_ids" {
  description = "Exactly two stable Availability Zone IDs in aws_region, ordered as zones A and B."
  type        = list(string)
  validation {
    condition     = length(var.availability_zone_ids) == 2 && length(distinct(var.availability_zone_ids)) == 2
    error_message = "availability_zone_ids must contain exactly two distinct AZ IDs."
  }
}

variable "environment" {
  description = "Deployment environment tag and naming component."
  type        = string
  default     = "learning"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must contain only lowercase letters, digits, and hyphens."
  }
}
