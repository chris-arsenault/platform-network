resource "aws_wafv2_web_acl" "alb" {
  name        = "${local.prefix}-alb-waf"
  description = "WAF protecting the reverse proxy ALB."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.prefix}-commonrules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-alb-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${local.prefix}-alb-waf"
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.reverse_proxy.arn
  web_acl_arn  = aws_wafv2_web_acl.alb.arn
}
