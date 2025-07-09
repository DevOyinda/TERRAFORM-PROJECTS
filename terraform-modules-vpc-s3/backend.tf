terraform {
  backend "s3" {
    bucket         = "kudir-terraform-bucket-001"     # Replace with your S3 bucket
    key            = "terraform.tfstate"
    region         = "us-east-2"                        # Adjust if needed
    encrypt        = true
    dynamodb_table = "your-lock-table"                  # Replace with your DynamoDB lock table
  }
}
