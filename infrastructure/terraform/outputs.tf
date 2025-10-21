output "alb_dns_name" {
  description = "DNS name of the public ALB fronting the reverse proxy."
  value       = aws_lb.reverse_proxy.dns_name
}

output "reverse_proxy_instance_id" {
  description = "Instance ID of the reverse proxy EC2 host."
  value       = module.reverse_proxy.instance_id
}

output "reverse_proxy_private_ip" {
  description = "Private IP address of the reverse proxy EC2 host."
  value       = module.reverse_proxy.private_ip
}

output "cognito_user_pool_id" {
  description = "Cognito user pool controlling ALB authentication."
  value       = aws_cognito_user_pool.alb.id
}

output "cognito_user_pool_domain" {
  description = "Cognito hosted UI domain used for ALB authentication."
  value       = aws_cognito_user_pool_domain.alb.domain
}

output "waf_arn" {
  description = "ARN of the WAF Web ACL protecting the ALB."
  value       = aws_wafv2_web_acl.alb.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain."
  value       = aws_cloudfront_distribution.reverse_proxy.domain_name
}

output "reverse_proxy_certificate_arn" {
  description = "ARN of the ACM certificate used by the ALB and CloudFront."
  value       = aws_acm_certificate_validation.reverse_proxy.certificate_arn
}
