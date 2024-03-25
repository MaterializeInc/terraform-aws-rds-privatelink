terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "3.3.2"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
