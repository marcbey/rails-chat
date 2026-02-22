bucket         = "rails-chat-terraform-state"
key            = "staging/terraform.tfstate"
region         = "eu-central-1"
dynamodb_table = "terraform-locks"
encrypt        = true
