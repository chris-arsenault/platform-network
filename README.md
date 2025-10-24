# VPN Infrastructure Overview

This repository manages the AWS-based VPN hub that exposes a home-lab NAS through
WireGuard. Terraform provisions the cloud resources while Nix builds the AMIs that
bootstrap each EC2 role (WireGuard hub, reverse proxy, and NAT instance).

## Layout

- `infrastructure/terraform/` – Terraform configuration for networking, security,
  and application infrastructure.
- `infrastructure/nixos/` – NixOS modules and flake targets used to pre-bake the
  EC2 images consumed by Terraform.
- `.github/workflows/` – CI pipelines that build/publish AMIs and apply Terraform.

See the READMEs in `infrastructure/terraform/` and `infrastructure/nixos/` for
role-specific guidance.

## CI workflow

The `deploy.yml` workflow:

1. Builds the Nix AMIs, uploads them to S3, imports them into EC2, and writes the
   resulting AMI IDs to SSM under `/${PREFIX}/amis/<role>`.
2. Runs `terraform plan`/`apply`, relying on Terraform data sources to pick up the
   freshly published AMI IDs.

Ensure the GitHub secrets `OIDC_ROLE`, `AMI_BUCKET`, `PREFIX`, `TRUENAS_PUB_KEY`,
`HOME_LAN_CIDR`, and `DOMAIN` are set before triggering deployments.
