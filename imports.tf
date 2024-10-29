import {
  to = google_compute_firewall.default_allow_ssh
  id = "default-allow-ssh"
}

import {
  to = google_compute_disk.trailblaze_boot_disk
  id = "trailblaze-init"
}

import {
  to = google_compute_disk.graph_data_disk
  id = "graph-data-disk"
}
