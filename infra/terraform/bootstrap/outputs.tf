output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.id
}

output "lock_table_name" {
  value = aws_dynamodb_table.tf_lock.name
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}
