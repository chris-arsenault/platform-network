resource "aws_cognito_user_pool" "alb" {
  name = "${local.prefix}-alb-users"

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  mfa_configuration = "OFF"

  tags = {
    Name = "${local.prefix}-alb-users"
  }
}

resource "aws_cognito_user_pool_domain" "alb" {
  domain       = local.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.alb.id
}

resource "aws_cognito_user_pool_client" "alb" {
  name                                 = "${local.prefix}-alb-client"
  user_pool_id                         = aws_cognito_user_pool.alb.id
  generate_secret                      = false
  prevent_user_existence_errors        = "ENABLED"
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes = [
    "email",
    "openid",
    "profile"
  ]
  supported_identity_providers = ["COGNITO"]

  callback_urls = concat(
    [for host in local.reverse_proxy_hostnames : "https://${host}/oauth2/idpresponse"],
    ["https://${aws_lb.reverse_proxy.dns_name}/oauth2/idpresponse"]
  )

  logout_urls = concat(
    [for host in local.reverse_proxy_hostnames : "https://${host}/logout"],
    ["https://${aws_lb.reverse_proxy.dns_name}/logout"]
  )
}

resource "aws_cognito_user_group" "reverse_proxy" {
  name         = "reverse-proxy"
  user_pool_id = aws_cognito_user_pool.alb.id
  description  = "Users allowed to access the reverse proxy ALB."
}

resource "aws_cognito_identity_pool" "alb" {
  identity_pool_name               = "${local.prefix}-alb"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.alb.id
    provider_name           = aws_cognito_user_pool.alb.endpoint
    server_side_token_check = true
  }
}

data "aws_iam_policy_document" "cognito_auth_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["cognito-identity.amazonaws.com"]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "cognito-identity.amazonaws.com:aud"
      values   = [aws_cognito_identity_pool.alb.id]
    }

    condition {
      test     = "ForAnyValue:StringLike"
      variable = "cognito-identity.amazonaws.com:amr"
      values   = ["authenticated"]
    }
  }
}

resource "aws_iam_role" "cognito_authenticated" {
  name_prefix        = "${local.prefix}-cognito-auth-"
  assume_role_policy = data.aws_iam_policy_document.cognito_auth_assume.json
}

resource "aws_iam_role_policy" "cognito_authenticated" {
  name = "${local.prefix}-cognito-auth"
  role = aws_iam_role.cognito_authenticated.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-sync:*",
          "cognito-identity:*",
          "mobileanalytics:PutEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "alb" {
  identity_pool_id = aws_cognito_identity_pool.alb.id
  roles = {
    authenticated = aws_iam_role.cognito_authenticated.arn
  }
}
