terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "~> 0.145.0"
    }
  }
  required_version = ">=1.8"
}

provider "yandex" {
  token     = var.token
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.cloud_zone
  # service_account_key_file = file("~/.authorized_key.json")
}
