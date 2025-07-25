#http balancer
# HTTP Router
resource "yandex_alb_http_router" "router" {
  name = "k8s-router"
}

# Target Group для всех worker-узлов
resource "yandex_alb_target_group" "balancer-group" {
  name       = "balancer-group"
  depends_on = [yandex_compute_instance.k8s]

  dynamic "target" {
    for_each = { for k, v in yandex_compute_instance.k8s : k => v if k != "0" }
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}
# Backend Group для Grafana (NodePort 30080)
resource "yandex_alb_backend_group" "grafana-backend" {
  name = "grafana-backend"
  depends_on = [yandex_alb_target_group.balancer-group]
  http_backend {
    name             = "grafana"
    weight           = 1
    port             = 30080
    target_group_ids = ["${yandex_alb_target_group.balancer-group.id}"]
    
    healthcheck {
      timeout             = "3s"
      interval           = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/api/health"
      }
    }
  }
}

# Backend Group для DevCats (NodePort 30051)
resource "yandex_alb_backend_group" "devcats-backend" {
  name = "devcats-backend"
  depends_on = [yandex_alb_target_group.balancer-group]
  http_backend {
    name             = "devcats"
    weight           = 1
    port             = 30051
    target_group_ids = ["${yandex_alb_target_group.balancer-group.id}"]
    
    healthcheck {
      timeout             = "3s"
      interval           = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/"
      }
    }
  }
}


# Виртуальный хост с маршрутизацией
resource "yandex_alb_virtual_host" "virtual-host" {
  name           = "k8s-virtual-host"
  http_router_id = yandex_alb_http_router.router.id
  authority      = ["*"]
  
  depends_on = [
    yandex_alb_backend_group.grafana-backend,
    yandex_alb_backend_group.devcats-backend
  ]

  # Маршрут для Grafana
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

  # Маршрут для DevCats (все остальные запросы)
  route {
    name = "devcats-route"
    http_route {
      http_match {
        path {
          prefix = "/"
        }
      }
      http_route_action {
        backend_group_id = yandex_alb_backend_group.devcats-backend.id
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

  depends_on = [yandex_alb_virtual_host.virtual-host]
}
