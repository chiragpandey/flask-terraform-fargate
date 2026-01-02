provider "aws" {
  region                   = "us-east-1"
  shared_credentials_files = ["~/.aws/credentials"] # specify the path to your AWS credentials file
}

# The label of the provider block corresponds to the name of the provider in the required_providers list in your terraform block.

#-------- Custom VPC and Subnet Resources --------#

resource "aws_vpc" "flask-tf-fargate-vpc" {
  cidr_block           = "10.46.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true # we have to enable public IP addr as a part of this VPC

  tags = {
    Name = "flask-tf-fargate"
  }
}

#-------- Create IGW and assocoate with VPC --------#

resource "aws_internet_gateway" "flask-tf-fargate-igw" {
  vpc_id = aws_vpc.flask-tf-fargate-vpc.id # associating IGW with VPC

  tags = {
    Name = "flask-tf-fargate"
  }
}

#--------- Create 2 Public Subnets --------#

resource "aws_subnet" "flask-tf-fargate-publicsubnet1" {
  vpc_id                  = aws_vpc.flask-tf-fargate-vpc.id
  cidr_block              = "10.46.10.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # this is a public subnet

  tags = {
    Name = "flask-tf-fargate-public-subnet-1"
    Type = "public"
  }
}

resource "aws_subnet" "flask-tf-fargate-publicsubnet2" {
  vpc_id                  = aws_vpc.flask-tf-fargate-vpc.id
  cidr_block              = "10.46.11.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true # this is a public subnet

  tags = {
    Name = "flask-tf-fargate-public-subnet-2"
    Type = "public"
  }
}

#-------- Create Route Table for pubic subnets --------#

resource "aws_route_table" "flask-tf-fargate-publicRT" {
  vpc_id = aws_vpc.flask-tf-fargate-vpc.id

  route { # defining route to IGW for public access. It allows the public traffic to come in and out of the VPC
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.flask-tf-fargate-igw.id
  }

  tags = {
    Name = "flask-tf-fargate-public-rt"
  }
}

#-------- Associate Route Table with Public Subnets --------#
# Assosiate public subnet with public route table

resource "aws_route_table_association" "flask-tf-fargate-publicsubnet1-association1" {
  subnet_id      = aws_subnet.flask-tf-fargate-publicsubnet1.id
  route_table_id = aws_route_table.flask-tf-fargate-publicRT.id
}

resource "aws_route_table_association" "flask-tf-fargate-publicsubnet2-association2" {
  subnet_id      = aws_subnet.flask-tf-fargate-publicsubnet2.id
  route_table_id = aws_route_table.flask-tf-fargate-publicRT.id
}

#--------- Create 2 Private Subnets --------#

resource "aws_subnet" "flask-tf-fargate-privatesubnet1" {
  vpc_id                  = aws_vpc.flask-tf-fargate-vpc.id
  cidr_block              = "10.46.20.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false # this is a private subnet

  tags = {
    Name = "flask-tf-fargate-private-subnet-1"
    Type = "private"
  }
}

resource "aws_subnet" "flask-tf-fargate-privatesubnet2" {
  vpc_id                  = aws_vpc.flask-tf-fargate-vpc.id
  cidr_block              = "10.46.21.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false # this is a private subnet

  tags = {
    Name = "flask-tf-fargate-private-subnet-2"
    Type = "private"
  }
}

#--------- Create route table for private subnets --------#

resource "aws_route_table" "flask-tf-fargate-privateRT" {
  vpc_id = aws_vpc.flask-tf-fargate-vpc.id

  tags = {
    Name = "flask-tf-fargate-private-rt"
  }

}

#-------- Associate route table with private subnets --------#

resource "aws_route_table_association" "flask-tf-fargate-privatesubnet1-association1" {
  subnet_id      = aws_subnet.flask-tf-fargate-privatesubnet1.id
  route_table_id = aws_route_table.flask-tf-fargate-privateRT.id
}

resource "aws_route_table_association" "flask-tf-fargate-privatesubnet2-association2" {
  subnet_id      = aws_subnet.flask-tf-fargate-privatesubnet2.id
  route_table_id = aws_route_table.flask-tf-fargate-privateRT.id
}

#--------- Create a Security Group --------#

resource "aws_security_group" "flask-tf-fargate-sg" {
  name        = "flask-tf-fargate-sg"
  description = "Security Group for Flask TF Fargate Application"
  vpc_id      = aws_vpc.flask-tf-fargate-vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-tf-fargate-sg"
  }
}

#--------- Create Target Group for ELB --------#

resource "aws_lb_target_group" "CustomTG" {
  name        = "flask-tf-fargate-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.flask-tf-fargate-vpc.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3" # number of consecutive successful health checks before considering the target healthy
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2" # number of consecutive failed health checks before considering the target unhealthy
  }

  tags = {
    Name = "flask-tf-fargate-tg"
  }
}

#--------- Create Security Group for ELB --------#

resource "aws_security_group" "elb_SG" {
  name        = "flask-tf-fargate-elb-sg"
  description = "Security Group for ELB"
  vpc_id      = aws_vpc.flask-tf-fargate-vpc.id

  ingress {
    description = "Allow inbound HTTP from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow inbound HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flask-tf-fargate-elb-security-group"
  }
}

#--------- Fetch subnet IDs dynamically --------#

data "aws_subnets" "GetSubnets" {
  depends_on = [aws_subnet.flask-tf-fargate-publicsubnet1, aws_subnet.flask-tf-fargate-publicsubnet2] # Ensure subnets are created before fetching
  filter {
    name   = "tag:Type"
    values = ["public"]
  }

  filter {
    name   = "vpc-id"
    values = [aws_vpc.flask-tf-fargate-vpc.id]
  }
}

#---------------Create LB instance ---------------#

resource "aws_alb" "CustomELB" {
  name            = "flask-tf-fargate-elb"
  depends_on      = [aws_subnet.flask-tf-fargate-publicsubnet1, aws_subnet.flask-tf-fargate-publicsubnet2]
  internal        = false
  security_groups = [aws_security_group.elb_SG.id]
  subnets         = data.aws_subnets.GetSubnets.ids
  tags = {
    Name = "flask-tf-fargate-elb"
  }
}

#--------- Create Listener for ELB --------#

resource "aws_alb_listener" "CustomELBListener" {
  load_balancer_arn = aws_alb.CustomELB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.CustomTG.arn
      }
      stickiness { # Enable stickiness for session persistence
        enabled  = true
        duration = 28800
      }
    }
  }
}

# Terraform data sources to automatically fetch the latest Ubuntu AMI

# data "aws_ami" "ubuntu" {
#   most_recent = true

#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
#   }

#   owners = ["099720109477"] # Canonical is the owner ID for official Ubuntu images

# }

# resource "aws_instance" "flask-tf-fargate-ec2" {
#     ami           = data.aws_ami.ubuntu.id
#     instance_type = "t2.micro"
#     subnet_id     = aws_subnet.flask-tf-fargate-publicsubnet1.id
#     security_groups = [aws_security_group.flask-tf-fargate-sg.name]

#   tags = {
#     Name = "flask-tf-fargate-ec2"
#   }
# }

