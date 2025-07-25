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

 lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image_id]
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

# Условия проверки наличия локальных ключей и извлечение из переменных при отсутствии.
locals {
     ssh_key = fileexists("~/.ssh/tagir.pub") ? file("~/.ssh/tagir.pub") : var.ssh_public_key
     ssh_private_key = fileexists("~/.ssh/id_rsa") ? file("~/.ssh/id_rsa") : var.ssh_private_key
     subnet_map = {
    "public1" = yandex_vpc_subnet.public1.id
    "public2" = yandex_vpc_subnet.public2.id
  }
}

resource "null_resource" "kubespray_inventory" {
  triggers = {
    # Триггеры для пересоздания при изменении IP
    master_ip = yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address
    workera_ip = yandex_compute_instance.k8s["1"].network_interface[0].nat_ip_address
    workerb_ip = yandex_compute_instance.k8s["2"].network_interface[0].nat_ip_address
  }

  connection {
    type        = "ssh"
    user        = var.vm_username
    private_key = local.ssh_private_key
    host        = yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "cat <<EOF > /home/${var.vm_username}/.ssh/id_rsa",
      "${local.ssh_private_key}",
      "EOF",
      # Set proper permissions
      "chmod 600 /home/${var.vm_username}/.ssh/id_rsa",
      "chown ${var.vm_username}:${var.vm_username} /home/${var.vm_username}/.ssh/id_rsa",
      "sudo apt-get update && sudo apt-get install -y git;",
      # Проверяем существование директории kubespray
      "if [ ! -d \"/home/${var.vm_username}/kubespray\" ]; then",
      "sudo -u ${var.vm_username} git clone https://github.com/kubernetes-sigs/kubespray.git /home/${var.vm_username}/kubespray",
      "fi",
      "mkdir -p /home/${var.vm_username}/kubespray/inventory/mycluster",
      "sudo -u ${var.vm_username} cp -r /home/${var.vm_username}/kubespray/inventory/sample/group_vars /home/${var.vm_username}/kubespray/inventory/mycluster/",
      "cat <<EOF > /home/${var.vm_username}/kubespray/inventory/mycluster/inventory.ini",
      "[kube_control_plane]",
      "node1 ansible_host=${yandex_compute_instance.k8s["0"].network_interface[0].ip_address} #ip=${yandex_compute_instance.k8s["0"].network_interface[0].ip_address} etcd_member_name=etcd1",
      "[etcd:children]",
      "kube_control_plane",
      "[kube_node]",
      "node2 ansible_host=${yandex_compute_instance.k8s["1"].network_interface[0].ip_address} #ip=${yandex_compute_instance.k8s["1"].network_interface[0].ip_address}",
      "node3 ansible_host=${yandex_compute_instance.k8s["2"].network_interface[0].ip_address} #ip=${yandex_compute_instance.k8s["2"].network_interface[0].ip_address}",
      "EOF",
      #Добавляем параметры для nginx ingress
      "cat <<EOF > /home/${var.vm_username}/kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml",
      "ingress_nginx_enabled: true",
      "ingress_nginx_service_type: LoadBalancer",
      "helm_enabled: false",
      "registry_enabled: false",
      "metrics_server_enabled: false",
      "local_path_provisioner_enabled: false",
      "local_volume_provisioner_enabled: false",
      "gateway_api_enabled: false",
      "ingress_nginx_enabled: false",
      "node_feature_discovery_enabled: false",
      "EOF",

      # Ждем завершения копирования
      "sync",
      # Проверяем существование файла (для отладки)
      "ls -la /home/${var.vm_username}/kubespray/inventory/mycluster/group_vars/k8s_cluster/",
      "cat <<EOF >> /home/${var.vm_username}/kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml",
      "supplementary_addresses_in_ssl_keys: [\"${yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address}\"]",
      "EOF",
      "chown -R ${var.vm_username}:${var.vm_username} /home/${var.vm_username}/kubespray",
      "sudo apt-get update -q",
      "sudo apt-get install -y python3-pip python3-netaddr net-tools mc bind9utils",
      "pip install -U -r /home/${var.vm_username}/kubespray/requirements.txt",
      "echo 'export PATH=\"/home/${var.vm_username}/.local/bin:$PATH\"' | sudo -u ${var.vm_username} tee -a /home/${var.vm_username}/.bashrc",
      "sudo -u ${var.vm_username} bash -c 'source /home/${var.vm_username}/.bashrc'",
      "sudo -i -u ${var.vm_username} bash -c 'cd /home/${var.vm_username}/kubespray && ansible-playbook -i inventory/mycluster/inventory.ini -u ${var.vm_username} --become --become-user=root --private-key=/home/tagir/.ssh/id_rsa cluster.yml'",
      "sudo cp /etc/kubernetes/admin.conf /tmp/admin.conf",
      "sudo chown ${var.vm_username}:${var.vm_username} /tmp/admin.conf"
    ]
  }

  depends_on = [
    yandex_compute_instance.k8s["0"],
    yandex_compute_instance.k8s["1"],
    yandex_compute_instance.k8s["2"]
  ]
}

resource "null_resource" "copy_kubeconfig" {
  triggers = {
    master_ip = yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address
  }

  provisioner "local-exec" {
    command = <<-EOT
    if [ -n "$GITHUB_ACTIONS" ]; then
      echo "Running in GitHub Actions - saving to artifacts"
      mkdir -p ~/.ssh
      echo "${local.ssh_private_key}" > ~/.ssh/id_rsa
      chmod 600 ~/.ssh/id_rsa
      scp -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ${var.vm_username}@${yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address}:/tmp/admin.conf ./admin.conf
      mkdir -p ./kubeconfig-artifact
      cp ./admin.conf ./kubeconfig-artifact/kubeconfig
      echo "kubeconfig copied to artifact directory"
    else
      echo "Running locally - saving to ~/kube_config"
      scp -o StrictHostKeyChecking=no ${var.vm_username}@${yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address}:/tmp/admin.conf ~/kube_config
    fi
  EOT
  }

  depends_on = [
    null_resource.kubespray_inventory
  ]
}

resource "null_resource" "cleanup_admin_conf" {
  triggers = {
    kubeconfig_copied = null_resource.copy_kubeconfig.id  # Зависит от копирования
  }

  connection {
    type        = "ssh"
    user        = var.vm_username
    private_key = "${local.ssh_private_key}"
    host        = yandex_compute_instance.k8s["0"].network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = ["rm -f /tmp/admin.conf"]
  }

  depends_on = [null_resource.copy_kubeconfig]
}

resource "yandex_vpc_security_group" "k8s" {
  name        = "k8s-security-group"
  network_id  = yandex_vpc_network.cloud-netology.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [ "0.0.0.0/0" ]
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = [ "10.0.20.0/24", "10.0.21.0/24" ]
  }

  ingress {
    protocol       = "ANY"
    v4_cidr_blocks = [ var.my_ip ]
  }

  ingress {
    protocol       = "TCP"
    port           = 6443
    v4_cidr_blocks = [ "10.0.20.0/24", "10.0.21.0/24", var.my_ip ]
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

output "node_public_ip" {
  value = [
           for k8s in yandex_compute_instance.k8s : k8s.network_interface[0].nat_ip_address
          ]
  description = "node nat ip"
}

output "node_private_ip" {
  value = [
           for k8s in yandex_compute_instance.k8s : k8s.network_interface[0].ip_address
          ]
  description = "node ip"
}
