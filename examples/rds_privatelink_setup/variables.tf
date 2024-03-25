variable "aws_region" {
  description = "AWS region for the resources."
  default     = "us-east-1"
  type        = string
}

variable "mz_rds_instance_name" {
  description = "The name of the RDS instance."
  type        = string
}

variable "mz_egress_ips" {
  description = "The list of CIDR blocks to allow egress traffic to."
  type        = list(string)
}
