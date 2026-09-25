terraform {
  backend "s3" {
    bucket = "YOUR_TERRAFORM_STATE_BUCKET"
    key    = "prod/terraform.tfstate"
    region = "ap-south-1"
  }
}
