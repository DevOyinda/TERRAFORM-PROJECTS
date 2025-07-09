provider "aws" {
  region = "us-east-2"  # Change this to your desired AWS region
}

# Create a Security Group
resource "aws_security_group" "terraform_sg" {
  name        = "terraform-security-group"
  description = "Allow SSH and HTTP access"

  # Allow SSH (port 22) from anywhere (use your own IP for security)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP (port 80) for web traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 Instance and Attach the Security Group
resource "aws_instance" "terraform_instance" {
  ami                    = "ami-0d0f28110d16ee7d6"  # Specify your desired AMI ID  
  instance_type          = "t2.micro"  
  key_name               = "my-terraform"  # Specify your key pair name  
  vpc_security_group_ids = [aws_security_group.terraform_sg.id]  # Attach security group

  tags = {
    Name = "terraform-instance"
  }
}

# Create an AMI from the Instance
resource "aws_ami_from_instance" "terraform_ami" {  
  name               = "terraform-ami"  
  description        = "Example AMI created with Terraform"  
  source_instance_id = aws_instance.terraform_instance.id  
}

provider "aws" {
    region = "us-east-1"  # Change this to your desired AWS region"
    }

resource "aws_key_pair" "example_keypair" {
    key_name   = "example-keypair"
    public_key = file("C:/Users/kudir/.ssh/id_rsa.pub")  # Replace with the path to your public key file"
    }

resource "aws_instance" "example_instance" {
    ami           = "ami-0c55b159cbfafe1f0"  # Specify your desired AMI ID
    instance_type = "t2.micro"
    key_name      = aws_key_pair.example_keypair.key_name
    vpc_security_group_ids = "sg-0123456789abcdef0"  # Specify your security group ID
    user_data = <<-EOF              
    #!/bin/bash              
    yum update -y         
    yum install -y httpd              
    systemctl start httpd              
    systemctl enable httpd              
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html              
    EOF
}

output "public_ip" {
    value = aws_instance.example_instance.public_ip
    }
