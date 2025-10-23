data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "reverse_proxy" {
  name              = "/aws/vpn/${local.prefix}/reverse-proxy"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "wireguard" {
  name              = "/aws/vpn/${local.prefix}/wireguard"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "nat" {
  name              = "/aws/vpn/${local.prefix}/nat"
  retention_in_days = 30
}

locals {
  cloudwatch_region = data.aws_region.current.id

  reverse_proxy_logs_query = <<-EOT
SOURCE '/aws/vpn/${local.prefix}/reverse-proxy'
| fields @timestamp, @logStream, @message
| sort @timestamp desc
| limit 20
EOT

  wireguard_logs_query = <<-EOT
SOURCE '/aws/vpn/${local.prefix}/wireguard'
| filter @logStream like /wg-quick|wg-healthcheck/
| fields @timestamp, @logStream, @message
| sort @timestamp desc
| limit 20
EOT

  nat_logs_query = <<-EOT
SOURCE '/aws/vpn/${local.prefix}/nat'
| fields @timestamp, @logStream, @message
| sort @timestamp desc
| limit 20
EOT

  reverse_proxy_cpu_expression     = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"CPUUtilization\"}', 'Average', 300)", module.reverse_proxy.autoscaling_group_name)
  reverse_proxy_network_expression = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"NetworkOut\"}', 'Average', 300)", module.reverse_proxy.autoscaling_group_name)
  reverse_proxy_status_expression  = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"StatusCheckFailed\"}', 'Average', 300)", module.reverse_proxy.autoscaling_group_name)

  wireguard_cpu_expression     = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"CPUUtilization\"}', 'Average', 300)", module.wireguard.autoscaling_group_name)
  wireguard_network_expression = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"NetworkOut\"}', 'Average', 300)", module.wireguard.autoscaling_group_name)

  nat_network_expression = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"NetworkOut\"}', 'Average', 300)", module.nat.autoscaling_group_name)
  nat_status_expression  = format("SEARCH('{AWS/EC2,AutoScalingGroupName=\"%s\",MetricName=\"StatusCheckFailed\"}', 'Average', 300)", module.nat.autoscaling_group_name)

  dashboard_widgets = [
    {
      type   = "log"
      x      = 0
      y      = 0
      width  = 8
      height = 6
      properties = {
        query  = local.reverse_proxy_logs_query
        region = local.cloudwatch_region
        title  = "Reverse Proxy Recent Logs"
      }
    },
    {
      type   = "log"
      x      = 8
      y      = 0
      width  = 8
      height = 6
      properties = {
        query  = local.wireguard_logs_query
        region = local.cloudwatch_region
        title  = "WireGuard Recent Logs"
      }
    },
    {
      type   = "log"
      x      = 16
      y      = 0
      width  = 8
      height = 6
      properties = {
        query  = local.nat_logs_query
        region = local.cloudwatch_region
        title  = "NAT Recent Logs"
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 6
      width  = 12
      height = 6
      properties = {
        metrics = [
          [
            {
              expression = local.reverse_proxy_cpu_expression
              label      = "Reverse Proxy CPU Utilization"
              id         = "e1"
            }
          ],
          [
            {
              expression = local.reverse_proxy_network_expression
              label      = "Reverse Proxy Network Out"
              id         = "e2"
              yAxis      = "right"
            }
          ]
        ]
        region  = local.cloudwatch_region
        title   = "Reverse Proxy Performance"
        view    = "timeSeries"
        period  = 300
        stacked = false
        stat    = "Average"
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 6
      width  = 12
      height = 6
      properties = {
        metrics = [
          [
            {
              expression = local.wireguard_cpu_expression
              label      = "WireGuard CPU Utilization"
              id         = "e3"
            }
          ],
          [
            {
              expression = local.wireguard_network_expression
              label      = "WireGuard Network Out"
              id         = "e4"
              yAxis      = "right"
            }
          ]
        ]
        region  = local.cloudwatch_region
        title   = "WireGuard Performance"
        view    = "timeSeries"
        period  = 300
        stacked = false
        stat    = "Average"
      }
    },
    {
      type   = "metric"
      x      = 0
      y      = 12
      width  = 12
      height = 6
      properties = {
        metrics = [
          [
            {
              expression = local.nat_network_expression
              label      = "NAT Network Out"
              id         = "e5"
            }
          ]
        ]
        region  = local.cloudwatch_region
        title   = "NAT Throughput"
        view    = "timeSeries"
        period  = 300
        stacked = false
        stat    = "Average"
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = 12
      width  = 12
      height = 6
      properties = {
        metrics = [
          [
            {
              expression = local.reverse_proxy_status_expression
              label      = "Reverse Proxy Status Checks"
              id         = "e6"
            }
          ],
          [
            {
              expression = local.nat_status_expression
              label      = "NAT Status Checks"
              id         = "e7"
            }
          ]
        ]
        region  = local.cloudwatch_region
        title   = "EC2 Status Health"
        view    = "timeSeries"
        period  = 300
        stacked = false
        stat    = "Average"
      }
    }
  ]
}

resource "aws_cloudwatch_dashboard" "operations" {
  dashboard_name = "${local.prefix}-operations"
  dashboard_body = jsonencode({
    widgets = local.dashboard_widgets
  })
}
