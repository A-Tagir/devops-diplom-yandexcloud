#KMS ключ
resource "yandex_kms_symmetric_key" "key-state" {
  name                = "s3state-bucket"
  description         = "key_for_encrypt_bucket"
  default_algorithm   = "AES_128"
  rotation_period     = "8760h"
  deletion_protection = true
  lifecycle {
    prevent_destroy = false
  }
}

#Сервисный аккаунт для шифрования
resource "yandex_iam_service_account" "state-sa" {
  name = "bucket-encrypt-account"
}

// Назначение роли сервисному аккаунту
resource "yandex_resourcemanager_folder_iam_member" "bucket-admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.state-sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "kms-encrypter" {
  folder_id = var.folder_id
  role      = "kms.keys.encrypterDecrypter"
  member    = "serviceAccount:${yandex_iam_service_account.state-sa.id}"
}

// Создание статического ключа доступа
resource "yandex_iam_service_account_static_access_key" "tf-static-key" {
  service_account_id = yandex_iam_service_account.state-sa.id
  description        = "static access key for object storage"
}
