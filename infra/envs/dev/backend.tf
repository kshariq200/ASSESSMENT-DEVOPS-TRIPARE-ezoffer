terraform {
  backend "s3" {
    bucket = "YOUR_TERRAFORM_STATE_BUCKET"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"
  }
}
