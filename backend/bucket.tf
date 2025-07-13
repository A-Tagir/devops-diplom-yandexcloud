resource "yandex_storage_bucket" "tagir-tf-bucket" {
  bucket    = "tagir-tf-bucket"
  max_size  = 1073741824
  acl       = "private"
  folder_id = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.tf-static-key.access_key
  secret_key = yandex_iam_service_account_static_access_key.tf-static-key.secret_key
  force_destroy=false
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = yandex_kms_symmetric_key.key-state.id
        sse_algorithm     = "aws:kms"
      }
    }
  }
provisioner "local-exec" {
  command = "echo export S3_ACCESS_KEY=${yandex_iam_service_account_static_access_key.tf-static-key.access_key} > ../backend/backend.tfvars"
}

provisioner "local-exec" {
  command = "echo export S3_SECRET_KEY=${yandex_iam_service_account_static_access_key.tf-static-key.secret_key} >> ../backend/backend.tfvars"
}
depends_on = [
    yandex_resourcemanager_folder_iam_member.bucket-admin,
    yandex_resourcemanager_folder_iam_member.kms-encrypter,
  ]
}