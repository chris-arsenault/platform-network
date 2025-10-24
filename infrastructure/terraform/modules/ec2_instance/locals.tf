locals {
  instance_tags = { Name = var.name }
  volume_tags   = { Name = "${var.name}-vol" }
  eni_tags      = { Name = "${var.name}-eni" }
  eip_tags      = { Name = "${var.name}-eip" }
  schedule_name = lower("${var.name}-nightly-refresh")
}
