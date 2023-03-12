#Configure an ALB with an Elastic IP in Terraform, you would typically follow these 
#-steps: 

#Create an Elastic IP resouce: Define a new Elastic IP resource in your Terraform
#-configureation file by specifying the region in which the Elastic IP
#-is to be allocated. You can also associate a tag with the resource to 
#-make it easier to identify. 


resource "aws_eip" "wordpress-eip" {
  region = "us-east-1"
  tags = {
    Name = "wordpress-eip"
  }
}


#Create an ALB resource: Define a new Application Load baancer resource, specifying
#the listeners and target groups that it should use. You can also associate any 
#relevant tags with the ALB.

resource "aws_lb" "wordpress_alb" {
  name               = "wordpress_alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ingress.id]
  subnets            = [aws_subnet.public.*.id]

  tags = {
    Name = "wordpress_alb"
  }
}
#Create a listener on port 80 with redirect action

resource "aws_lb_listener" "alb_http_listener" {
    load_balancer_arn = aws_lb.wordpress_alb.arn
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
    load_balancer_arn = aws_lb.wordpress_alb.arn
    port              = 443
    protocol          = "HTTPS"
    ssl_policy        = ""
   
    default_action {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.my_target_group.arn

    }

}

#Create an ALB Target group resource: Define a new target group resource that
#specifies the targets (e.g, EC2 instaces) that the ALB should route traffic to.
#You can also specify any health checks or other options for the target group. 

resource "aws_lb_target_group" "my_target_group" {
  name_prefix      = "my-target-group"
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
    Name = "my-target-group"
  }
}


#Associate the Elastic IP with the ALB: Use the 'aws_lib_listener' resource to 
#associate the Elastic IP with the ALB listener. 

resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}
  # associate with the Elastic IP
  # use the allocation_id attribute to get the ID of the Elastic IP resource created earlier
  # use the "arn:aws:ec2:::eip/ID" format for the value of the "target_group_arn" attribute
  # where "ID" is the ID of the Elastic IP resource
  depends_on = [aws_eip.wordpress_eip]

  # attach the EIP to the listener
  # note that "target_group_arn" is actually an EIP resource in this context
  default_action {
    type             = "redirect"
  }
    redirect {
      port        = "80"
      protocol    = "HTTP"
      status_code = "HTTP_301"
    }
    target_group_arn = "arn:aws:ec2:::eip/$"


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

#Custom Domain Validation
resource "aws_acm_certificate" "cert" {
  domain_name       = "gayansdeveopsjourney.co.uk"
  validation_method = "DNS"

  }


#eferencing domain_validation_options With for_each Based Resources

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

