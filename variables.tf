# AWS Details
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

# List of variables that the user would need to change

# The name of the existing RDS instance
variable "mz_rds_instance_name" {
  description = "The name of the existing RDS instance"
}

# The VPC ID of the existing RDS instance
variable "mz_rds_vpc_id" {
  description = "The VPC ID of the existing RDS instance"
}

# Endpoint Service Acceptance Required (true/false)
variable "mz_acceptance_required" {
  description = "Endpoint Service Manual Acceptance Required (true/false)"
  default     = false
  type        = bool
}

# Schedule expression for how often to run the Lambda function
variable "schedule_expression" {
  description = "Schedule expression for how often to run the Lambda function"
  type        = string
  default     = "rate(5 minutes)"
}
