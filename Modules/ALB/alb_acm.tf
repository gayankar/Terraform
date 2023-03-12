provider "aws" {
  region = "us-east-1"
}

resource "aws_lb" "my_lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_sg.id]
  subnets            = [aws_subnet.my_subnet_1.id, aws_subnet.my_subnet_2.id]
}

resource "aws_lb_listener" "my_lb_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn = aws_acm_certificate.my_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_target_group.arn
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "my-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
}

resource "aws_security_group" "my_sg" {
  name_prefix = "my-sg"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_acm_certificate" "my_certificate" {
  domain_name       = "example.com"
  validation_method = "DNS"

  tags = {
    Name = "my-certificate"
  }
}

resource "aws_acm_certificate_validation" "my_certificate_validation" {
  certificate_arn = aws_acm_certificate.my_certificate.arn

  validation_record_fqdns = [
    aws_route53_record.my_certificate_validation[0].fqdn,
    aws_route53_record.my_certificate_validation[1].fqdn,
  ]
}

resource "aws_route53_record" "my_certificate_validation" {
  count = length(aws_acm_certificate.my_certificate.domain_validation_options)

  name = aws_acm_certificate.my_certificate.domain_validation_options[count.index].resource_record_name
  type = aws_acm_certificate.my_certificate.domain_validation_options[count.index].resource_record_type
  zone_id = aws_route53_zone.my_zone.id
  records = [aws_acm_certificate.my_certificate.domain_validation_options[count.index].resource_record_value]
  ttl = 60
}
