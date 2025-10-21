# Repository Guidelines
Use this guide when extending the Terraform that exposes the home-lab NAS through an AWS WireGuard hub.

## Project Structure & Module Organization
- `infrastructure/terraform/` houses the entire stack (`providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, and `terraform.tfvars`).
- WireGuard cloud resources live directly in `main.tf`; use locals for opinionated defaults unless a value must come from tfvars.
- `infrastructure/terraform/templates/` stores the instance `user_data.sh.tpl`. Sanitized peer samples stay in `config/`; never commit real keys or PSKs.

## Build, Test, and Development Commands
- `terraform init` sets up providers, remote state, and module caches; rerun after backend or provider version changes.
- `terraform fmt -recursive` and `terraform validate` enforce formatting and schema checks; pair them with `tflint --config .tflint.hcl` for AWS linting.
- `terraform plan -out plan.tfplan` previews infrastructure changes; apply with `terraform apply plan.tfplan` only after review.
- `terraform output -raw home_peer_config` prints the NAS WireGuard config generated from `peer_home.conf.tpl`; rerun after the EC2 instance finishes bootstrapping (or run `terraform refresh`) so the server public key has been captured.

## Coding Style & Naming Conventions
- Target Terraform 1.x, use 2-space indentation, and order blocks variables → locals → resources → outputs for readability.
- Keep resource identifiers prefixed via the `resource_prefix` variable (defaults to `vpn`), keep the tfvars file focused on `resource_prefix`, `home_lan_cidr`, and peer public keys, and tag AWS assets with owner/contact metadata where relevant.
- Pin provider and module versions via `required_version` and `required_providers`; run `pre-commit run --all-files` when hooks exist.

## Testing Guidelines
- Run `terraform validate` and `tflint` on every branch; add Terratest cases in `test/` for module-level assertions (CIDRs, subnet counts, security rules).
- After `terraform apply`, verify that `terraform plan` reports “No changes” to guard against configuration drift.
- Update routing notes in `docs/peering-matrix.md` whenever peer IPs, ports, or AllowedIPs change so NAS call-home instructions stay accurate.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat:`, `fix:`, `infra:`, `chore:`, `docs:`) with ≤72-character summaries and optional ticket IDs like `VPN-123`.
- PR descriptions should capture purpose, impacted resources, validation commands run, and either the plan diff inline or an attached `plan.tfplan`.
- Squash review-only fixups before merging; use draft PRs to socialize large topology or state backend changes early.

## Security & Configuration Tips
- Source secrets from AWS SSM Parameter Store or Secrets Manager via data resources; never keep plaintext credentials in Git.
- Restrict security groups to WireGuard UDP traffic and trusted IP ranges, preferring SSM Session Manager over SSH for troubleshooting.
- Rotate EC2 key pairs and WireGuard peer keys regularly and track the process in `docs/operations.md`.
