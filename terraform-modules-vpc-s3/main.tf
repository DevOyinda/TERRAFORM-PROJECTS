provider "aws" {
  region = "us-east-2"  # Change if needed
}

module "vpc" {
  source = "./modules/vpc"
  # Add variables if needed
}

module "s3_bucket" {
  source = "./modules/s3"
  # Add variables if needed
}
