provider "dns" {}

resource "aws_route53_record" "cognito_auth_alias" {
  zone_id = local.route53_zone_id
  name    = local.cognito_auth_domain
  type    = "A"

  alias {
    name                   = aws_cognito_user_pool_domain.alb.cloudfront_distribution
    zone_id                = aws_cognito_user_pool_domain.alb.cloudfront_distribution_zone_id
    evaluate_target_health = false
  }
}

data "dns_cname_record_set" "auth" {
  host       = local.cognito_auth_domain
  depends_on = [aws_route53_record.cognito_auth_alias]
}

# Optional: enforce target match
locals {
  cname_ok = contains(data.dns_cname_record_set.auth.cnames, aws_cognito_user_pool_domain.alb.cloudfront_domain)
}

resource "null_resource" "dns_ready" {
  triggers = { ok = tostring(local.cname_ok) }
  lifecycle {
    precondition {
      condition     = local.cname_ok
      error_message = "CNAME not propagated yet"
    }
  }
}
