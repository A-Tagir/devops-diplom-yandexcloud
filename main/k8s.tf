data "yandex_compute_image" "ubuntu-2204-lts" {
  family = var.vm_family
}

data "template_file" "cloudinit" {
  template = file("./cloud-init.yml")

  vars = {
  username = var.vm_username
  ssh_public_key = local.ssh_key
 }
}

resource "yandex_compute_instance" "k8s" {
  for_each = {
  0 = "master"
  1 = "workera"
  2 = "workerb"
  }

  name = each.value
  platform_id  = var.vm_platform_id
  zone = var.each_vm[each.key].zone

  resources {
    cores = var.each_vm[each.key].cpu
    memory = var.each_vm[each.key].ram
    core_fraction = var.each_vm[each.key].core_fraction
  }
  
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu-2204-lts.image_id
      size = var.each_vm[each.key].disk_volume
    }
  }
  scheduling_policy {
    preemptible = var.each_vm[each.key].preemptible
  }
  network_interface {
    subnet_id = local.subnet_map[var.each_vm[each.key].subnet_name]
    nat = var.each_vm[each.key].nat
    security_group_ids = [yandex_vpc_security_group.k8s.id]
  }
  metadata = {
    user-data          = data.template_file.cloudinit.rendered 
    serial-port-enable = var.each_vm[each.key].serial-console
    ssh-keys           = local.ssh_key
  }

}

locals {
     ssh_key = file("/home/tiger/.ssh/tagir.pub")
     subnet_map = {
    "public1" = yandex_vpc_subnet.public1.id
    "public2" = yandex_vpc_subnet.public2.id
  }
}

resource "yandex_vpc_security_group" "k8s" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.cloud-netology.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

output "node_name" {
  value = [
           for k8s in yandex_compute_instance.k8s : k8s.name
          ]
  description = "node name"
}

output "node_ip" {
  value = [
           for k8s in yandex_compute_instance.k8s : k8s.network_interface[0].nat_ip_address
          ]
  description = "node ip"
}
