# System Boot Disk
#   The boot disk should be initialized with everything needed
#   to run Graphhopper.
#   - Compatible operating system
#   - JRE (17+)
resource "google_compute_disk" "trailblaze_boot_disk" {
  name = "trailblaze-init"
  zone = var.primary_zone
  type = "pd-balanced"
  size = 10
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
  name = "graph-data-disk"
  description = "stores graphhopper data"
  zone = var.primary_zone
  type = "pd-balanced"
  size = 20
}

resource "google_compute_image" "system-image" {
  disk_size_gb = 10
  lifecycle {
    create_before_destroy = true
  }
  name              = "system-image"
  project           = var.project_id
  source_disk       = google_compute_disk.trailblaze_boot_disk.self_link
  storage_locations = [var.primary_region]
}

resource "google_compute_image" "data-image" {
  disk_size_gb = 20
  lifecycle {
    create_before_destroy = true
  }
  name              = "data-image"
  project           = var.project_id
  source_disk       = google_compute_disk.graph_data_disk.self_link
  storage_locations = [var.primary_region]
}
