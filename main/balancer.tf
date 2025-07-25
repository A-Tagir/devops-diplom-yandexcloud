#http balancer
# HTTP Router
resource "yandex_alb_http_router" "router" {
  name = "k8s-router"
}

# Target Group для всех worker-узлов
resource "yandex_lb_target_group" "balancer-group" {
  name       = "k8s-target-group"
  depends_on = [yandex_compute_instance.k8s]

  dynamic "target" {
    for_each = { for k, v in yandex_compute_instance.k8s : k => v if k != "0" }
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}
