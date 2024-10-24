resource "google_compute_network" "default" {
  name = "network"
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
    health_check      = google_compute_http_health_check.graphhopper_health_check.id
    initial_delay_sec = 300
  }
  base_instance_name = "graphhopper-instance"
  target_size        = 2
}

data "google_compute_instance_group" "default" {
  self_link = google_compute_instance_group_manager.default.instance_group
}

# Autoscale instance group from 1-3
#   instances, depending on CPU usage. 
resource "google_compute_autoscaler" "default" {
  name    = "trailblaze-autoscaler"
  project = var.project_id
  zone    = "us-central1-c"
  target  = google_compute_instance_group_manager.default.id

  autoscaling_policy {
    max_replicas    = 3
    min_replicas    = 2
    cooldown_period = 120

    cpu_utilization {
      target = 0.7
    }
  }
  depends_on = [
    google_compute_instance_group_manager.default
  ]
}

# Instance Template for a production graphhopper instance. 
#   Contains a boot disk and a data disk.
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
