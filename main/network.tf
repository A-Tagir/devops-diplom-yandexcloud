resource "yandex_vpc_network" "cloud-netology" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "public1" {
  name           = "cloud-net-public-zone-a"
  zone           = var.public1_zone
  network_id     = yandex_vpc_network.cloud-netology.id
  v4_cidr_blocks = var.public1_cidr
}

resource "yandex_vpc_subnet" "public2" {
  name           = "cloud-net-public-zone-b"
  zone           = var.public2_zone
  network_id     = yandex_vpc_network.cloud-netology.id
  v4_cidr_blocks = var.public2_cidr
}

resource "yandex_vpc_subnet" "public3" {
  name           = "cloud-net-public-zone-d"
  zone           = var.public3_zone
  network_id     = yandex_vpc_network.cloud-netology.id
  v4_cidr_blocks = var.public3_cidr
}

resource "yandex_vpc_subnet" "private1" {
  name           = "cloud-net-private-zone-a"
  zone           = var.private1_zone
  network_id     = yandex_vpc_network.cloud-netology.id
  v4_cidr_blocks = var.private1_cidr
}

resource "yandex_vpc_subnet" "private2" {
  name           = "cloud-net-private-zone-b"
  zone           = var.private2_zone
  network_id     = yandex_vpc_network.cloud-netology.id
  v4_cidr_blocks = var.private2_cidr
}

resource "yandex_vpc_subnet" "private3" {
  name           = "cloud-net-private-zone-d"
  zone           = var.private3_zone
  network_id     = yandex_vpc_network.cloud-netology.id
  v4_cidr_blocks = var.private3_cidr
}

