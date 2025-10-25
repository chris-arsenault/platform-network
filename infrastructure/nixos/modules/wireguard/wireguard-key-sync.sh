#!/usr/bin/env bash
set -euo pipefail
umask 077

token="$(@curl@ -sS -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' || true)"

if [ -z "$token" ]; then
  echo "failed to fetch IMDSv2 token" >&2
  exit 1
fi

aws_region="$(@curl@ -sS -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/placement/region || true)"

if [ -z "$aws_region" ]; then
  echo "failed to determine AWS region from metadata service" >&2
  exit 1
fi

secret_json="$(@aws@ secretsmanager get-secret-value --region "$aws_region" --secret-id "@secretArn@" --query SecretString --output text || true)"

if [ -z "$secret_json" ] || [ "$secret_json" = "null" ]; then
  secret_json='{"private":"PLACEHOLDER","public":"PLACEHOLDER"}'
fi

priv="$(@jq@ -r '.private' <<<"$secret_json")"
pub="$(@jq@ -r '.public' <<<"$secret_json")"

@mkdir@ -p /var/lib/wireguard
@chmod@ 700 /var/lib/wireguard

if [ "$priv" = "PLACEHOLDER" ] || [ -z "$priv" ] || [ "$priv" = "null" ]; then
  @wg@ genkey | @tee@ /var/lib/wireguard/server_private.key | @wg@ pubkey > /var/lib/wireguard/server_public.key
  priv="$(@cat@ /var/lib/wireguard/server_private.key)"
  pub="$(@cat@ /var/lib/wireguard/server_public.key)"
  @aws@ secretsmanager put-secret-value \
    --region "$aws_region" \
    --secret-id "@secretArn@" \
    --secret-string "$(@jq@ -n --arg priv "$priv" --arg pub "$pub" '{private:$priv,public:$pub}')"
else
  printf '%s' "$priv" > /var/lib/wireguard/server_private.key
  printf '%s' "$pub" > /var/lib/wireguard/server_public.key
fi

@chmod@ 600 /var/lib/wireguard/server_private.key

@aws@ ssm put-parameter \
  --region "$aws_region" \
  --name "@ssmPublicKeyPath@" \
  --type "String" \
  --value "$pub" \
  --overwrite
