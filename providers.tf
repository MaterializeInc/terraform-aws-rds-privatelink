terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "3.3.2"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.4.2"
    }
  }
}
