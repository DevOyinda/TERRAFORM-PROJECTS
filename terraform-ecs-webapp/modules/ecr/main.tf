resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"
  
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}

variable "repository_name" {
  type = string
  description = "Name of the ECR repository"
}
