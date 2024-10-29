provider "google" {
  project = var.project_id
  region  = var.primary_region
  zone    = var.primary_zone
}

resource "google_compute_http_health_check" "graphhopper_health_check" {
  name               = "graphhopper-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2
  port          = 80
  request_path  = "/health"
}


resource "google_compute_health_check" "default" {
  check_interval_sec = 10
  healthy_threshold  = 2
  name               = "trailblaze-lb-healthcheck"
  project            = var.project_id
  tcp_health_check {
    port         = 80
    proxy_header = "NONE"
  }
  timeout_sec         = 5
  unhealthy_threshold = 2
}

resource "google_compute_region_health_check" "default" {
  check_interval_sec = 10
  healthy_threshold  = 2
  name               = "server-healthcheck"
  project            = var.project_id
  region             = var.primary_region
  tcp_health_check {
    port         = 80
    proxy_header = "NONE"
  }
  timeout_sec         = 5
  unhealthy_threshold = 4
}

resource "google_compute_managed_ssl_certificate" "default" {
  name = "frontend-https-cert"
  lifecycle {
    create_before_destroy = true
  }

  managed {
    domains = [var.api_domain]
  }
}
