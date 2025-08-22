terraform {
  backend "s3" {
    # Configuration will be provided via backend-config during init
    # bucket         = "terraform-state-bucket"
    # key            = "infrastructure/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-state-lock"
    # encrypt        = true
  }
}