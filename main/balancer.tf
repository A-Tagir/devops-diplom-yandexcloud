# 1. Сначала создаем HTTP Router (не имеет зависимостей)
resource "yandex_alb_http_router" "router" {
  name = "k8s-router"
}

# 2. Создаем целевую группу
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

  # Явно указываем, что группа должна быть полностью создана перед использованием
  provisioner "local-exec" {
    command = "sleep 10" # Даем время для полной инициализации
  }
}

# 3. Создаем Backend Groups с явными зависимостями
resource "yandex_alb_backend_group" "grafana-backend" {
  name = "grafana-backend"
  depends_on = [
    yandex_lb_target_group.balancer-group,
    null_resource.wait_for_target_group
  ]

  http_backend {
    name             = "grafana-backend"
    weight           = 1
    port             = 30080
    target_group_ids = [yandex_lb_target_group.balancer-group.id]
    
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

resource "yandex_alb_backend_group" "web-app-backend" {
  name = "web-app-backend"
  depends_on = [
    yandex_lb_target_group.balancer-group,
    null_resource.wait_for_target_group
  ]

  http_backend {
    name             = "web-app-backend"
    weight           = 1
    port             = 30051
    target_group_ids = [yandex_lb_target_group.balancer-group.id]
    
    healthcheck {
      timeout             = "3s"
      interval           = "5s"
      healthy_threshold   = 2
      unhealthy_threshold = 2
      http_healthcheck {
        path = "/healthz"
      }
    }
  }
}

# Ресурс для явного ожидания готовности целевой группы
resource "null_resource" "wait_for_target_group" {
  depends_on = [yandex_lb_target_group.balancer-group]
  
  provisioner "local-exec" {
    command = "sleep 15" # Увеличенное время ожидания
  }
}

# 4. Виртуальный хост
resource "yandex_alb_virtual_host" "virtual-host" {
  name           = "k8s-virtual-host"
  http_router_id = yandex_alb_http_router.router.id
  authority      = ["*"]
  
  depends_on = [
    yandex_alb_backend_group.grafana-backend,
    yandex_alb_backend_group.web-app-backend
  ]

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

# 5. Application Load Balancer (создается последним)
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
