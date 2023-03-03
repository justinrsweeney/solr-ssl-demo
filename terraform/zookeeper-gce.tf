resource "google_service_account" "zookeeper_service_account" {
  account_id   = "zookeeper-service-account"
  display_name = "Zookeeper Service Account"
}

resource "google_project_iam_member" "zookeeper_service_account_gcs_role" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.zookeeper_service_account.email}"
}

resource "google_storage_bucket" "zookeeper_setup_bucket" {
  name = "${var.project_id}-zookeeper-setup-bucket"
  location = "US"
}

resource "google_storage_bucket_object" "zookeeper_setup" {
  name   = "zoo.cfg"
  source = "../zoo.cfg"
  bucket = google_storage_bucket.zookeeper_setup_bucket.name
}

# Create Zookeeper Compute Engine instances
resource "google_compute_instance" "zookeeper" {
  count = local.zookeeper-instances
  depends_on = [google_storage_bucket_object.zookeeper_setup]
  allow_stopping_for_update = true
  name         = "zookeeper-vm-${count.index}"
  machine_type = "e2-small"
  zone         = "us-central1-a"
  tags         = ["ssh"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  # Install Solr
  metadata = {
    startup-script = <<-EOF
  apt-get update
  apt-get install -yq rsync default-jre wget
  rm -f apache-zookeeper-3.8.1-bin.tar.gz*
  wget https://dlcdn.apache.org/zookeeper/zookeeper-3.8.1/apache-zookeeper-3.8.1-bin.tar.gz
  mkdir -p /opt/zookeeper-3.8.1
  tar xzf apache-zookeeper-3.8.1-bin.tar.gz -C /opt/zookeeper-3.8.1 --strip-components=1
  mkdir -p /var/lib/zookeeper
  gsutil cp gs://${google_storage_bucket.zookeeper_setup_bucket.name}/zoo.cfg /opt/zookeeper-3.8.1/conf/zoo.cfg
  echo "${count.index + 1}" >> /var/lib/zookeeper/myid
  /opt/zookeeper-3.8.1/bin/zkServer.sh start
  EOF
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      # Include this section to give the VM an external IP address
    }
  }

  service_account {
    email = google_service_account.zookeeper_service_account.email
    scopes = ["cloud-platform"]
  }
}