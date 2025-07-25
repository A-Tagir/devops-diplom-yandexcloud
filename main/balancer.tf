# Единая целевая группа для всех worker-узлов
resource "yandex_lb_target_group" "balancer-group" {
  name       = "balancer-group"
  depends_on = [yandex_compute_instance.k8s]

  dynamic "target" {
    for_each = { for k, v in yandex_compute_instance.k8s : k => v if k != "0" } # Исключаем master-узел
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

# Backend Group для Grafana (порт 30080)
resource "yandex_lb_backend_group" "grafana-backend" {
  name = "grafana-backend"

  http_backend {
    name             = "grafana-backend"
    weight           = 1
    port             = 30080
    target_group_ids = [yandex_lb_target_group.balancer-group.id]
  }
}

# Backend Group для web-app (порт 30051)
resource "yandex_lb_backend_group" "web-app-backend" {
  name = "web-app-backend"

  http_backend {
    name             = "web-app-backend"
    weight           = 1
    port             = 30051
    target_group_ids = [yandex_lb_target_group.balancer-group.id]
  }
}
