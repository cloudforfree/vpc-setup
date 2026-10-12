terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Bucket, key and region are passed at init time (-backend-config) by the workflows.
  # use_lockfile = native S3 state locking (no DynamoDB table needed).
  backend "s3" {
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "vpc-lab"
      ManagedBy = "terraform"
    }
  }
}
