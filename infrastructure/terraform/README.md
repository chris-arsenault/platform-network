# Terraform Stack

This directory houses the Terraform configuration for the AWS VPN hub.
Terraform pulls the latest AMI IDs from SSM (populated by the CI pipeline) and
provisions networking, security groups, IAM roles, ACME certificates, and the
WireGuard/NAT/reverse proxy instances.

## Prerequisites

- Terraform 1.6+ (CI pins 1.12.2 for plan/apply).
- AWS credentials with access to the state bucket and the target account.
- SSM parameters created by the AMI publishing pipeline under
  `/${prefix}/amis/{wireguard,nat,reverse-proxy}`.

## Common commands

Run all commands from this directory unless noted otherwise:

```bash
terraform init \
  -backend-config "bucket=<STATE_BUCKET>" \
  -backend-config "region=<AWS_REGION>"

terraform plan -out tfplan \
  -var "prefix=<PREFIX>" \
  -var "home_lan_cidr=<CIDR>" \
  -var "home_peer_public_key=<PUBKEY>" \
  -var "root_domain_name=<DOMAIN>"

terraform apply tfplan
```

The AMI IDs do **not** need to be passed as variables; the configuration reads
them via `data.aws_ssm_parameter`.

## Notes

- `terraform fmt -recursive` keeps formatting consistent.
- `tflint --config ../../.tflint.hcl` can be used for static analysis.
- After changes are applied, a follow-up `terraform plan` should return “No
  changes” to guard against drift.
