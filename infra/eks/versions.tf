terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "tf-state-590183753633"
    key          = "k8s-aws-portfolio/eks/terraform.tfstate"
    region       = "us-west-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-west-1"
  default_tags {
    tags = {
      Project   = "k8s-aws-portfolio"
      ManagedBy = "terraform"
    }
  }
}