resource "aws_s3_bucket" "bucket" {
  bucket = "kudir-terraform-bucket-002"  # Replace with a unique name
  force_destroy = true

  tags = {
    Name = "Terraform Created Resource Bucket"
  }
}
