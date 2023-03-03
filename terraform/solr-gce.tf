resource "google_service_account" "solr_service_account" {
  account_id   = "solr-service-account"
  display_name = "Solr Service Account"
}

resource "google_service_account_iam_member" "sign-as-self" {
  service_account_id = google_service_account.solr_service_account.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.solr_service_account.email}"
}

resource "google_project_iam_member" "solr_service_account_gcs_role" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.solr_service_account.email}"
}

resource "google_project_iam_member" "solr_service_account_ca_role" {
  project = var.project_id
  role    = "roles/privateca.auditor"
  member  = "serviceAccount:${google_service_account.solr_service_account.email}"
}

# Create Solr Compute Engine instances
resource "google_compute_instance" "solr" {
  count = local.solr-instances
  depends_on = [google_storage_bucket_object.solr_setup, google_storage_bucket_object.solr_tls_key_setup, google_privateca_certificate_authority.solr_ssl_ca, google_compute_instance.zookeeper]
  allow_stopping_for_update = true
  name         = "solr-vm-${count.index}"
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
  sudo apt-get update
  sudo apt-get install -yq rsync default-jre wget
  wget https://dlcdn.apache.org/solr/solr/9.1.1/solr-9.1.1.tgz
  tar xzf solr-9.1.1.tgz solr-9.1.1/bin/install_solr_service.sh --strip-components=2
  sudo bash ./install_solr_service.sh solr-9.1.1.tgz -n
  sudo chown -R solr:solr /opt/solr-9.1.1
  gcloud privateca certificates export solr-vm-${count.index}-cert --issuer-location us-central1 --issuer-pool ${google_privateca_ca_pool.default.name} --include-chain --output-file /tmp/solr-cert
  gsutil cp gs://${google_storage_bucket.solr_setup_bucket.name}/tls-cert-private-key /tmp/tls-cert-private-key
  gsutil cp gs://${google_storage_bucket.solr_setup_bucket.name}/solr-ca-cert /tmp/solr-ca-cert
  openssl pkcs12 -export -in /tmp/solr-cert -inkey /tmp/tls-cert-private-key -out /etc/solr-ssl.keystore.p12 -name solr-ssl -passout pass:fullstory
  keytool -noprompt -storepass fullstory -import -alias ca -file /tmp/solr-ca-cert -keystore /etc/solr-ssl.truststore.p12 -deststoretype PKCS12
  gsutil cp gs://${google_storage_bucket.solr_setup_bucket.name}/solr.in.sh /etc/default/solr.in.sh
  sudo chown solr:solr /etc/solr-ssl.keystore.p12
  sudo chown solr:solr /etc/solr-ssl.truststore.p12
  /opt/solr/server/scripts/cloud-scripts/zkcli.sh -zkhost zookeeper-vm-0:2181 -cmd clusterprop -name urlScheme -val https
  sudo /etc/init.d/solr start
  EOF
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.name

    access_config {
      # Include this section to give the VM an external IP address
    }
  }

  service_account {
    email = google_service_account.solr_service_account.email
    scopes = ["cloud-platform"]
  }
}

resource "google_storage_bucket" "solr_setup_bucket" {
  name = "${var.project_id}-solr-setup-bucket"
  location = "US"
}

resource "google_storage_bucket_object" "solr_setup" {
  name   = "solr.in.sh"
  source = "../solr.in.sh"
  bucket = google_storage_bucket.solr_setup_bucket.name
}

resource "google_storage_bucket_object" "solr_tls_key_setup" {
  name   = "tls-cert-private-key"
  content = tls_private_key.solr-ssl.private_key_pem
  bucket = google_storage_bucket.solr_setup_bucket.name
}

resource "google_storage_bucket_object" "solr_ca_cert_setup" {
  name   = "solr-ca-cert"
  content = google_privateca_certificate_authority.solr_ssl_ca.pem_ca_certificates[0]
  bucket = google_storage_bucket.solr_setup_bucket.name
}

resource "tls_cert_request" "solr-ssl" {
  count = local.solr-instances
  private_key_pem = tls_private_key.solr-ssl.private_key_pem

  subject {
    common_name  = "solr-vm-${count.index}"
    organization = "Justin Sweeney"
  }
  dns_names = ["solr-vm-${count.index}", "localhost"]
}

resource "google_privateca_certificate" "default" {
  count = local.solr-instances
  pool                  = google_privateca_ca_pool.default.name
  certificate_authority = google_privateca_certificate_authority.solr_ssl_ca.certificate_authority_id
  location              = "us-central1"
  lifetime              = "94608000s"
  name                  = "solr-vm-${count.index}-cert"
  pem_csr               = element(tls_cert_request.solr-ssl.*.cert_request_pem, count.index)
}