terraform {
  required_version = ">= 1.6.0"
  
  backend "s3" {
    bucket = "amir-app-prod"
    key = "k8s_infra/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true # S3 native locking
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37"
    }
    helm = {
        source = "hashicorp/helm"
        version = "~> 2.9.0"
      }
  }
}


# Provider Configuration
provider "aws" {
  region = var.aws_region
}
