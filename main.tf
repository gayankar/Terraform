terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}


#Create a VPC

resource "aws_vpc" "main" {
  cidr_block   = "192.168.0.0/16"

  tags = {
    Name = "wordpress_2_VPC"
  }
}

#Create a Public Subnet 

resource "aws_subnet" "Public" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "192.168.0.0/24"

    tags =  {
         Name = "Public Subnet"
    }
}


#Main Internet Gateway for VPC

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "wordpress_2_IG"
  }
}

#Route Table for Public Subnet

resource "aws_route_table" "Public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block= "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id

  }
#Create Route table Association

resource "aws_route_table_association" "public_route_table" {

  subnet_id = aws_subnet.Public.id
  route_table_id = aws_route_table.Public.id

}

#Create Security Group

resource "aws_security_group" "ingress" {
  name        = "allow_tls_ssh"
  description = "Allow TLS and ssh inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

 ingress {
    description      = "http from Anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress {
    description      = "SSH from Home "
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["86.11.84.99/32"]

  }


  tags = {
    Name = "Wordpress_2_SG"
  }
}
#Create NACL for Wordpress_2 site

resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

 egress {

    protocol       = "-1"
    rule_no        = 100
    action         = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 0
    to_port        = 0

}

 ingress {

    protocol       = "-1"
    rule_no        = 200
    action         = "allow"
    cidr_block     = "0.0.0.0/0"
    from_port      = 0
    to_port        = 0
 }


}

#NACL associatation with VPC and Subnet

resource "aws_network_acl_association" "main" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.Public.id
}

#Careate EC2 instnace
resource "aws_instance" "wordpress_2" {

  ami  = "ami-04bcb19e4c2aec503"
  instance_type = "t2.micro"
  key_name = "wordpress"
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.Public.id
  vpc_security_group_ids = [aws_security_group.ingress.id]

  tags = {
    Name = "Wordpres_2"
  }
}

