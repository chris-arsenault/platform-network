variable "prefix" {
  description = "Prefix for all resources"
  type        = string
}

variable "home_lan_cidr" {
  description = "CIDR block for the home network reachable via WireGuard."
  type        = string
}

variable "home_peer_public_key" {
  description = "WireGuard public key for the home/NAS peer."
  type        = string
}

variable "laptop_peer_public_key" {
  description = "Optional WireGuard public key for a roaming laptop peer."
  type        = string
  default     = ""
}

variable "root_domain_name" {
  description = "Route53 hosted zone (root domain) used for certificate validation and alias records"
  type        = string
}

variable "wireguard_ami_id" {
  description = "AMI ID for the WireGuard NixOS image."
  type        = string
}

variable "nat_ami_id" {
  description = "AMI ID for the NAT instance NixOS image."
  type        = string
}

variable "reverse_proxy_ami_id" {
  description = "AMI ID for the reverse proxy NixOS image."
  type        = string
}
