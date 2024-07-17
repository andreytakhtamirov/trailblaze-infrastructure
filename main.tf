provider "google" {
  project = var.project_id
  region  = "us-central1-a"
}

resource "google_compute_network" "default" {
  name = "network"
}

resource "google_compute_disk" "production_disk" {
  guest_os_features {
    type = "GVNIC"
  }
  guest_os_features {
    type = "IDPF"
  }
  guest_os_features {
    type = "SEV_CAPABLE"
  }
  guest_os_features {
    type = "SEV_LIVE_MIGRATABLE"
  }
  guest_os_features {
    type = "SEV_LIVE_MIGRATABLE_V2"
  }
  guest_os_features {
    type = "SEV_SNP_CAPABLE"
  }
  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }
  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }
  image                     = "https://www.googleapis.com/compute/beta/projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240307b"
  licenses                  = ["https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/licenses/ubuntu-2004-lts"]
  name                      = "production-disk"
  physical_block_size_bytes = 4096
  project                   = var.project_id
  size                      = 10
  type                      = "pd-balanced"
  zone                      = "us-central1-c"
}

resource "google_compute_disk" "graph_data_disk" {
  name    = "graph-data-disk"
  project = var.project_id
  size    = 30
  type    = "pd-balanced"
  zone    = "us-central1-c"
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

resource "google_compute_global_forwarding_rule" "default" {
  ip_address            = google_compute_global_address.default.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  name                  = "lb-frontend-forwarding-rule"
  port_range            = "443"
  project               = var.project_id
  target                = google_compute_target_https_proxy.default.id
}

resource "google_compute_global_forwarding_rule" "test" {
  ip_address            = google_compute_global_address.default.id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  name                  = "test-frontend-forwarding-rule"
  port_range            = "80"
  project               = var.project_id
  target                = google_compute_target_http_proxy.default.id
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

resource "google_compute_image" "system-image" {
  disk_size_gb = 10
  lifecycle {
    create_before_destroy = true
  }
  name              = "system-image"
  project           = var.project_id
  source_disk       = google_compute_disk.production_disk.self_link
  storage_locations = ["us-central1"]
}

resource "google_compute_image" "data-image" {
  disk_size_gb = 30
  lifecycle {
    create_before_destroy = true
  }
  name              = "data-image"
  project           = var.project_id
  source_disk       = google_compute_disk.graph_data_disk.self_link
  storage_locations = ["us-central1"]
}

resource "google_compute_global_address" "default" {
  address_type = "EXTERNAL"
  description  = "IP address reserved for trailblaze-graphhopper load balancer frontend"
  ip_version   = "IPV4"
  name         = "trailblaze-lb-ip"
  project      = var.project_id
}

data "google_compute_instance_group" "default" {
  self_link = google_compute_instance_group_manager.default.instance_group
}

resource "google_compute_instance_group_manager" "default" {
  zone    = "us-central1-c"
  name    = "instance-group-manager"
  project = var.project_id
  lifecycle {
    create_before_destroy = false
  }
  version {
    instance_template = google_compute_instance_template.graphhopper_template.id
    name              = "primary"
  }
  named_port {
    name = "http"
    port = 80
  }
  auto_healing_policies {
    health_check      = google_compute_health_check.default.id
    initial_delay_sec = 300
  }
  base_instance_name = "graphhopper-instance"
  target_size        = 1
}

resource "google_compute_autoscaler" "default" {
  name    = "trailblaze-autoscaler"
  project = var.project_id
  zone    = "us-central1-c"
  target  = google_compute_instance_group_manager.default.id

  autoscaling_policy {
    max_replicas    = 3
    min_replicas    = 1
    cooldown_period = 120

    cpu_utilization {
      target = 0.7
    }
  }
  depends_on = [
    google_compute_instance_group_manager.default
  ]
}

resource "google_compute_instance_template" "graphhopper_template" {
  disk {
    auto_delete  = true
    boot         = true
    mode         = "READ_WRITE"
    source_image = google_compute_image.system-image.self_link
  }
  disk {
    auto_delete  = true
    mode         = "READ_WRITE"
    source_image = google_compute_image.data-image.self_link
  }
  lifecycle {
    create_before_destroy = false
  }
  confidential_instance_config {
    enable_confidential_compute = false
  }
  machine_type = "n2d-custom-4-17920"
  metadata = {
    startup-script = <<-EOF
        #!/bin/bash
        mkdir ~/data
        sudo mount /dev/sdb ~/data
        cd ~/data
        bash start-app.sh
      EOF
    ssh-keys       = "${var.account_email}:${file("gcp_ssh.pub")}"
  }
  min_cpu_platform = "AMD Milan"
  name             = "graphhopper-instance-template"
  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }
    network    = google_compute_network.default.id
    stack_type = "IPV4_ONLY"
  }
  project = var.project_id
  reservation_affinity {
    type = "ANY_RESERVATION"
  }
  scheduling {
    automatic_restart           = false
    instance_termination_action = "STOP"
    on_host_maintenance         = "TERMINATE"
    preemptible                 = true
    provisioning_model          = "SPOT"
  }
  service_account {
    email  = "compute-prod@${var.project_id}.iam.gserviceaccount.com"
    scopes = ["https://www.googleapis.com/auth/devstorage.full_control", "https://www.googleapis.com/auth/logging.write", "https://www.googleapis.com/auth/monitoring.write", "https://www.googleapis.com/auth/service.management.readonly", "https://www.googleapis.com/auth/servicecontrol", "https://www.googleapis.com/auth/trace.append"]
  }
  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_vtpm                 = true
  }
  tags = ["http-server", "lb-health-check", "default-allow-ssh"]
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

resource "google_compute_url_map" "default" {
  default_service = google_compute_backend_service.default.id
  name            = "loadbalancer"
  project         = var.project_id
}

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

resource "google_storage_bucket" "trailblaze-graphhopper-bucket" {
  force_destroy            = false
  location                 = "US-WEST1"
  name                     = var.bucket_name
  project                  = var.project_id
  public_access_prevention = "enforced"
  storage_class            = "STANDARD"
}
