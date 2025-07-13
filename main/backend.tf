terraform {
  backend "s3" {
    endpoints =  {
     s3 = "https://storage.yandexcloud.net"
    }
    bucket = "tagir-tf-bucket"
    region = "ru-central1"
    key = "tagir-tf-bucket/terraform.tfstate"
    skip_region_validation = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true   
    skip_s3_checksum            = true
    use_path_style            = true

  }
}