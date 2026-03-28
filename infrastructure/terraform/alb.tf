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
  target_type = "ip"

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
  target_id        = module.reverse_proxy.private_ip
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
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }

  depends_on = [aws_acm_certificate_validation.reverse_proxy]
}

# --- Platform-wide CORS preflight handler ---
# A single Lambda responds to all OPTIONS requests with CORS headers.
# Projects do not need their own OPTIONS listener rules or CORS middleware
# for preflight handling — only for injecting CORS headers on actual responses.

data "archive_file" "cors_handler" {
  type        = "zip"
  output_path = "${path.module}/cors-handler.zip"

  source {
    content  = <<-PY
def handler(event, context):
    return {
        "statusCode": 204,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS, HEAD",
            "Access-Control-Allow-Headers": "Authorization, Content-Type",
            "Access-Control-Max-Age": "86400"
        },
        "body": ""
    }
PY
    filename = "index.py"
  }
}

resource "aws_iam_role" "cors_handler" {
  name = "${local.prefix}-cors-handler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cors_handler" {
  role       = aws_iam_role.cors_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "cors_handler" {
  function_name    = "${local.prefix}-cors-handler"
  role             = aws_iam_role.cors_handler.arn
  handler          = "index.handler"
  runtime          = "python3.13"
  timeout          = 3
  memory_size      = 128
  filename         = data.archive_file.cors_handler.output_path
  source_code_hash = data.archive_file.cors_handler.output_base64sha256
}

resource "aws_lb_target_group" "cors_handler" {
  name        = "${local.prefix}-cors-tg"
  target_type = "lambda"
}

resource "aws_lb_target_group_attachment" "cors_handler" {
  target_group_arn = aws_lb_target_group.cors_handler.arn
  target_id        = aws_lambda_function.cors_handler.arn
  depends_on       = [aws_lambda_permission.cors_handler]
}

resource "aws_lambda_permission" "cors_handler" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cors_handler.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.cors_handler.arn
}

resource "aws_lb_listener_rule" "cors_preflight" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  condition {
    http_request_method {
      values = ["OPTIONS"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cors_handler.arn
  }
}

# --- Reverse proxy listener rule (Cognito auth + forward to on-prem) ---

resource "aws_lb_listener_rule" "reverse_proxy" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  condition {
    host_header {
      values = local.reverse_proxy_hostnames
    }
  }

  action {
    type  = "authenticate-cognito"
    order = 1

    authenticate_cognito {
      user_pool_arn              = nonsensitive(data.aws_ssm_parameter.cognito_user_pool_arn.value)
      user_pool_client_id        = nonsensitive(data.aws_ssm_parameter.alb_cognito_client_id.value)
      user_pool_domain           = nonsensitive(data.aws_ssm_parameter.cognito_domain.value)
      on_unauthenticated_request = "authenticate"
      scope                      = "openid email profile"
      session_cookie_name        = "alb-auth"
      session_timeout            = 3600
    }
  }

  action {
    type             = "forward"
    order            = 2
    target_group_arn = aws_lb_target_group.reverse_proxy.arn
  }
}
