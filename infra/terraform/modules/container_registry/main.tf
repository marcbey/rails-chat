resource "aws_ecr_repository" "this" {
  name                 = "${var.name_prefix}/rails-chat"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
