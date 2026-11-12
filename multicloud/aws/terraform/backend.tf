terraform {
  backend "s3" {
    bucket       = "shopnow-dev-7k2q-tfstate"
    key          = "platform.tfstate"
    region       = "us-east-1"
    use_lockfile = true   # S3-native lock, Terraform 1.10+
    # dynamodb_table = "shopnow-dev-tflock"  # older setups
  }
}
