# IP address for accessing the load balancer frontend
resource "google_compute_global_address" "default" {
  address_type = "EXTERNAL"
  description  = "IP address reserved for trailblaze-graphhopper load balancer frontend"
  ip_version   = "IPV4"
  name         = "trailblaze-lb-ip"
  project      = var.project_id
}

# Map address to backend service
resource "google_compute_url_map" "default" {
  default_service = google_compute_backend_service.default.id
  name            = "loadbalancer"
  project         = var.project_id
}

# Backend service to access compute instance group
resource "google_compute_backend_service" "default" {
  connection_draining_timeout_sec = 300
  health_checks                   = [google_compute_health_check.default.id]
  load_balancing_scheme           = "EXTERNAL_MANAGED"
  locality_lb_policy              = "LEAST_REQUEST"
  name                            = "trailblaze-lb-backend"
  port_name                       = "http"
  project                         = var.project_id
  protocol                        = "HTTP"
  session_affinity                = "NONE"
  timeout_sec                     = 30
  backend {
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1
    group           = data.google_compute_instance_group.default.id
    max_utilization = 0.8
  }
}

# Forward HTTPS traffic from global address to proxy
resource "google_compute_global_forwarding_rule" "default" {
  ip_address            = google_compute_global_address.default.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  name                  = "lb-frontend-forwarding-rule"
  port_range            = "443"
  project               = var.project_id
  target                = google_compute_target_https_proxy.default.id
}

# Forward HTTP traffic from global address to proxy
# Useful to test resources while waiting for the main HTTPS certificate to be issued.
# resource "google_compute_global_forwarding_rule" "test" {
#   ip_address            = google_compute_global_address.default.id
#   ip_protocol           = "TCP"
#   load_balancing_scheme = "EXTERNAL_MANAGED"
#   name                  = "test-frontend-forwarding-rule"
#   port_range            = "80"
#   project               = var.project_id
#   target                = google_compute_target_http_proxy.default.id
# }

resource "google_compute_target_https_proxy" "default" {
  name             = "loadbal-target-proxy"
  project          = var.project_id
  quic_override    = "NONE"
  ssl_certificates = [google_compute_managed_ssl_certificate.default.id]
  url_map          = google_compute_url_map.default.self_link
}

resource "google_compute_target_http_proxy" "default" {
  name    = "loadbal-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.default.self_link
}

# Allow ssh, http, https
resource "google_compute_firewall" "default_allow_ssh" {
  allow {
    ports    = ["22", "80", "443"]
    protocol = "tcp"
  }
  description   = "Allow SSH from anywhere"
  direction     = "INGRESS"
  name          = "default-allow-ssh"
  network       = google_compute_network.default.name
  priority      = 65534
  project       = var.project_id
  source_ranges = ["0.0.0.0/0"]
}
