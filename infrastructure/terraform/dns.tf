resource "aws_route53_record" "apex_placeholder" {
  zone_id = local.route53_zone_id
  name    = var.root_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.reverse_proxy.domain_name
    zone_id                = aws_cloudfront_distribution.reverse_proxy.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "wireguard" {
  zone_id = local.route53_zone_id
  name    = "wg.${var.root_domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.wireguard.dns_name
    zone_id                = aws_lb.wireguard.zone_id
    evaluate_target_health = false
  }
}
