resource "aws_lb" "reverse_proxy" {
  name               = "${local.prefix}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.public.id,
    aws_subnet.public_b.id
  ]

  enable_deletion_protection = false

  tags = {
    Name = "${local.prefix}-alb"
  }
}

resource "aws_lb_target_group" "reverse_proxy" {
  name        = "${local.prefix}-proxy-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "${local.prefix}-proxy-tg"
  }
}

resource "aws_lb_target_group_attachment" "reverse_proxy_instance" {
  target_group_arn = aws_lb_target_group.reverse_proxy.arn
  target_id        = module.reverse_proxy.instance_id
  port             = 80
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.reverse_proxy.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.reverse_proxy.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.reverse_proxy.certificate_arn

  default_action {
    type = "authenticate-cognito"

    authenticate_cognito {
      user_pool_arn              = aws_cognito_user_pool.alb.arn
      user_pool_client_id        = aws_cognito_user_pool_client.alb.id
      user_pool_domain           = aws_cognito_user_pool_domain.alb.domain
      on_unauthenticated_request = "authenticate"
      scope                      = "openid email profile"
      session_cookie_name        = "alb-auth"
      session_timeout            = 3600
    }
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reverse_proxy.arn
  }

  depends_on = [aws_acm_certificate_validation.reverse_proxy]
}
