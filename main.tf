provider "google" {
  project = var.project_id
  region  = "us-central1-a"
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
  region             = "us-central1"
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

resource "google_storage_bucket" "trailblaze-graphhopper-bucket" {
  force_destroy            = false
  location                 = "US-WEST1"
  name                     = var.bucket_name
  project                  = var.project_id
  public_access_prevention = "enforced"
  storage_class            = "STANDARD"
}
