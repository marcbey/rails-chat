resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.name_prefix}/rails-chat"
  retention_in_days = 14
}
