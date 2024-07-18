# System Boot Disk
#   The boot disk should be initialized with everything needed
#   to run Graphhopper.
#   - Compatible operating system
#   - JRE (17+)
resource "google_compute_disk" "production_disk" {
  image                     = "https://www.googleapis.com/compute/beta/projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20240307b"
  licenses                  = ["https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/licenses/ubuntu-2004-lts"]
  name                      = "production-disk"
  physical_block_size_bytes = 4096
  project                   = var.project_id
  size                      = 10
  type                      = "pd-balanced"
  zone                      = "us-central1-c"
}

# Graphhopper Data Disk
#   The data disk contains Graphhopper configuration data:
#       - Graphhopper web server executable (.jar)
#       - Graph data directory
#       - Graphhopper configuration file
#       - Script to start the server (start-app.sh)
#       - Anything else that Graphhopper would need:
#           - Elevation data directory
#           - Custom model directory
resource "google_compute_disk" "graph_data_disk" {
  name    = "graph-data-disk"
  project = var.project_id
  size    = 30
  type    = "pd-balanced"
  zone    = "us-central1-c"
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
