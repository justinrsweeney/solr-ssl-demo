# VPC
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = "false"
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.10.0.0/24"
}

resource "google_compute_firewall" "ssh-rule" {
  name = "${var.project_id}-vpc-ssh"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "solr-non-tls-rule" {
  name = "${var.project_id}-vpc-solr-non-tls"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports = ["8983"]
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "solr-tls-rule" {
  name = "${var.project_id}-vpc-solr-tls"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports = ["8443"]
  }
  source_ranges = ["0.0.0.0/0"]
}