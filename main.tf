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

#Public Subnet with Default Route to Internet Gateway

resource "aws_subnet" "Public" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "192.168.0.0/24"
    availability_zone = "us-east-1a"
    tags =  {
         Name = "Public Subnet"
    }
}


#Public Subnet two

resource "aws_subnet" "Public-2" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "192.168.1.0/24"
    availability_zone = "us-east-1c"
    tags =  {
         Name = "Public Subnet - 2"
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

  tags = {
    Name = "Public Route Table"
  }
}

#Create Route table Association

resource "aws_route_table_association" "public_route_table" {

  subnet_id = aws_subnet.Public.id
  route_table_id = aws_route_table.Public.id

}

#Create Route table Association with Public2

resource "aws_route_table_association" "public_route_table-b" {
  subnet_id = aws_subnet.Public-2.id
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

#NACL association with VPC and Subnet

resource "aws_network_acl_association" "main" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.Public.id
 }

#NACL association with VPC and Subnet 2


resource "aws_network_acl_association" "main2" {
  network_acl_id = aws_network_acl.main.id
  subnet_id      = aws_subnet.Public-2.id
 }

#Careate EC2 instnace one
resource "aws_instance" "wordpress_1" {

  ami  = "ami-04bcb19e4c2aec503"
  instance_type = "t2.micro"
  key_name = "wordpress"
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.Public.id
  vpc_security_group_ids = [aws_security_group.ingress.id]

  tags = {
    Name = "Wordpress 1"
  }
}

resource "aws_instance" "wordpress_2" {

  ami  = "ami-04bcb19e4c2aec503"
  instance_type = "t2.micro"
  key_name = "wordpress"
  associate_public_ip_address = "true"
  subnet_id = aws_subnet.Public-2.id
  vpc_security_group_ids = [aws_security_group.ingress.id]

  tags = {
    Name = "Wordpress 2"
  }
}



#Configure an ALB with an Elastic IP in Terraform, you would typically follow these
#-steps:

#Create an Elastic IP resouce: Define a new Elastic IP resource in your Terraform
#-configureation file by specifying the region in which the Elastic IP
#-is to be allocated. You can also associate a tag with the resource to
#-make it easier to identify.


resource "aws_eip" "wordpress-eip" {

  tags = {
    Name = "wordpress-eip"
  }
}
#Create an ALB resource: Define a new Application Load baancer resource, specifying
#the listeners and target groups that it should use. You can also associate any
#relevant tags with the ALB.

resource "aws_lb" "wordpress-alb" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ingress.id]
  subnets            = [aws_subnet.Public.id, aws_subnet.Public-2.id]

  tags = {
    Name = "wordpress-alb"
  }
}
#Create a listener on port 80 with redirect action

resource "aws_lb_listener" "alb_http_listener" {
    load_balancer_arn = aws_lb.wordpress-alb.arn
    port              = 80
    protocol          = "HTTP"

    default_action {
        type = "redirect"

        redirect {
            port        =   443
            protocol    =   "HTTPS"
            status_code =   "HTTP_301"
        }
    }

}

#Create a listener on port 443 with forward action

resource "aws_lb_listener" "alb_https_listener" {
    load_balancer_arn = aws_lb.wordpress-alb.arn
    port              = 443
    protocol          = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
    certificate_arn   = aws_acm_certificate.cert.arn

    default_action {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.my-gp.arn

    }

}

#Create an ALB Target group resource: Define a new target group resource that
#specifies the targets (e.g, EC2 instaces) that the ALB should route traffic to.
#You can also specify any health checks or other options for the target group.

resource "aws_lb_target_group" "my-gp" {
  name_prefix      = "my-gp"
  port             = 80
  protocol         = "HTTP"
  target_type      = "instance"
  vpc_id           = aws_vpc.main.id

  health_check {
    healthy_threshold   = 2
    interval            = 300
    protocol            = "HTTP"
    timeout             = 60
    unhealthy_threshold = 5
  }

  tags = {
    Name = "my-gp"
  }
}


#Associate the Elastic IP with the ALB: Use the 'aws_lib_listener' resource to
#associate the Elastic IP with the ALB listener.

resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.wordpress-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my-gp.arn
  }
}

#create ACM Cert
    resource "aws_acm_certificate" "cert" {
  domain_name       = "gayansdeveopsjourney.co.uk"
  validation_method = "DNS"

  tags = {
    Environment = "test"
  }

  lifecycle {
    create_before_destroy = true
  }
}

#Referencing domain_validation_options With for_each Based Resources

resource "aws_route53_record" "cert" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = "Z029094020D20Z60GSA4D"
}
                   
