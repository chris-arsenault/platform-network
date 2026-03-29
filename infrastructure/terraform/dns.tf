resource "aws_route53_record" "wireguard" {
  zone_id = local.route53_zone_id
  name    = "wg.${local.root_domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.wireguard.dns_name
    zone_id                = aws_lb.wireguard.zone_id
    evaluate_target_health = false
  }
}
