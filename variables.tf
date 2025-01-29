# List of variables that the user would need to change

# The names of the existing RDS instances
variable "mz_rds_instance_details" {
  description = "List of objects containing RDS instance names and their corresponding unique listener ports"
  type = list(object({
    name          = string
    listener_port = number
  }))
}

# The name of the NLB to be created
variable "mz_nlb_name" {
  description = "The name of the NLB to be created"
  type        = string
  default     = "mz-rds-lb"
}

# The VPC ID of the existing RDS instance
variable "mz_rds_vpc_id" {
  description = "The VPC ID of the existing RDS instance"
  type        = string
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

# Enable cross zone load balancing
variable "cross_zone_load_balancing" {
  description = "Enables cross zone load balancing for the NLB"
  type        = bool
  default     = true
}
