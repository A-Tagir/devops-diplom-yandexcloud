###cloud vars

variable "vm_family" {
  type        = string
  description = "image for cluster"
  default = "ubuntu-2204-lts"
}

variable "vm_platform_id" {
  type = string
  description = "nodes platform id"
  default = "standard-v1"

}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "cloud_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}
variable "public1_cidr" {
  type        = list(string)
  default     = ["10.0.20.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "public2_cidr" {
  type        = list(string)
  default     = ["10.0.21.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "private1_cidr" {
  type        = list(string)
  default     = ["192.168.20.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "private2_cidr" {
  type        = list(string)
  default     = ["192.168.21.0/24"]
  description = "https://cloud.yandex.ru/docs/vpc/operations/subnet-create"
}

variable "vpc_name" {
  type        = string
  default     = "cloud-netology"
  description = "VPC network & subnet name"
}

variable "token" {
  type        = string
  default     = ""
  sensitive   = true
  description = "IAM token"
}
   
variable "private1_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "private2_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "public1_zone" {
  type        = string
  default     = "ru-central1-a"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "public2_zone" {
  type        = string
  default     = "ru-central1-b"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "metadata_resources" {
   type = map(any)
   description = "VM metadata map"
}

variable "vm_username" {
  type = string
  description = "nodes admin username"
  default = "tagir"
}

variable "each_vm" {
  type = list(object(
  { vm_name=string, 
    cpu=number, 
    ram=number, 
    disk_volume=number, 
    core_fraction=number,
    preemptible=bool,
    nat=bool,
    serial-console=number,
    subnet_name   = string
    zone = string
  }))
  default = [
    { # master
      vm_name       = "master"
      cpu           = 2
      ram           = 4
      disk_volume   = 20
      core_fraction = 20
      preemptible   = false
      nat           = true
      serial-console = 0
      subnet_name = "public1"
      zone = "ru-central1-a"
    },
    { # workera
      vm_name       = "workera"
      cpu           = 2
      ram           = 4
      disk_volume   = 20
      core_fraction = 20
      preemptible   = true
      nat           = true
      serial-console = 0
      subnet_name = "public1"
      zone = "ru-central1-a"
    },
    { #workerb
      vm_name       = "workerb"
      cpu           = 2
      ram           = 4
      disk_volume   = 20
      core_fraction = 20
      preemptible   = true
      nat           = true
      serial-console = 0
      subnet_name = "public2"
      zone = "ru-central1-b"
    }
  ]
}

