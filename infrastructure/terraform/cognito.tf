# Shared Cognito pool details from platform-services (via SSM)

data "aws_ssm_parameter" "cognito_user_pool_arn" {
  name = "/platform/cognito/user-pool-arn"
}

data "aws_ssm_parameter" "cognito_domain" {
  name = "/platform/cognito/domain"
}

data "aws_ssm_parameter" "alb_cognito_client_id" {
  name = "/platform/cognito/alb-client-id"
}
