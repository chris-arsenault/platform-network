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
  default = null
}

variable "root_domain_name" {
  description = "Route53 hosted zone (root domain) used for certificate validation and alias records"
  type        = string
}
