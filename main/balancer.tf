# HTTP Router для маршрутизации (created first as it has no dependencies)
resource "yandex_alb_http_router" "router" {
  name = "k8s-router"
}

# Target Group для web-app (порт 30051)
resource "yandex_lb_target_group" "web-app-group" {
  name       = "web-app-group"
  depends_on = [yandex_compute_instance.k8s]

  dynamic "target" {
    for_each = { for k, v in yandex_compute_instance.k8s : k => v if k != "0" } # Исключаем master-узел
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

# Target Group для Grafana (порт 30050)
resource "yandex_lb_target_group" "grafana-group" {
  name       = "grafana-group"
  depends_on = [yandex_compute_instance.k8s]

  dynamic "target" {
    for_each = { for k, v in yandex_compute_instance.k8s : k => v if k != "0" } # Исключаем master-узел
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

# Backend Group для web-app (порт 30051)
resource "yandex_alb_backend_group" "web-app-backend" {
  name = "web-app-backend"
  depends_on = [yandex_lb_target_group.web-app-group]

  http_backend {
    name             = "web-app-backend"
    weight           = 1
    port             = 30051
    target_group_ids = [yandex_lb_target_group.web-app-group.id]
  }
}

# Backend Group для Grafana (порт 30050)
resource "yandex_alb_backend_group" "grafana-backend" {
  name = "grafana-backend"
  depends_on = [yandex_lb_target_group.grafana-group]

  http_backend {
    name             = "grafana-backend"
    weight           = 1
    port             = 30080
    target_group_ids = [yandex_lb_target_group.grafana-group.id]
  }
}

# Виртуальный хост с правилами маршрутизации
resource "yandex_alb_virtual_host" "virtual-host" {
  name           = "k8s-virtual-host"
  http_router_id = yandex_alb_http_router.router.id
  authority      = ["*"] # Принимаем любой домен
  depends_on = [
    yandex_alb_backend_group.web-app-backend,
    yandex_alb_backend_group.grafana-backend
  ]

  # Маршрут для Grafana (/monitor)
  route {
    name = "grafana-route"
    http_route {
      http_match {
        path {
          prefix = "/monitor"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.grafana-backend.id
      }
    }
  }

  # Маршрут для web-app (все остальные запросы)
  route {
    name = "web-app-route"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.web-app-backend.id
      }
    }
  }
}

# Application Load Balancer
resource "yandex_alb_load_balancer" "alb" {
  name               = "k8s-alb"
  network_id         = yandex_vpc_network.cloud-netology.id
  security_group_ids = [yandex_vpc_security_group.k8s.id]

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = yandex_vpc_subnet.public1.id
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {}
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.router.id
      }
    }
  }

  depends_on = [
    yandex_alb_virtual_host.virtual-host
  ]
}
