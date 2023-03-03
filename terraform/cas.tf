resource "random_id" "ca_pool_suffix" {
  byte_length      = 8
}

resource "google_project_service" "privateca_api" {
  service            = "privateca.googleapis.com"
  disable_on_destroy = false
}

resource "tls_private_key" "solr-ssl" {
  algorithm = "RSA"
}

resource "google_privateca_ca_pool" "default" {
  name     = "solr-ssl-ca-pool-${random_id.ca_pool_suffix.hex}"
  location = "us-central1"
  tier     = "ENTERPRISE"
  publishing_options {
    publish_ca_cert = true
    publish_crl     = true
  }
  issuance_policy {
    baseline_values {
      ca_options {
        is_ca = false
      }
      key_usage {
        base_key_usage {
          digital_signature = true
          key_encipherment  = true
        }
        extended_key_usage {
          server_auth = true
          client_auth = true
        }
      }
    }
  }
}

resource "google_privateca_certificate_authority" "solr_ssl_ca" {
  certificate_authority_id = "solr-ssl-authority"
  location                 = "us-central1"
  pool                     = google_privateca_ca_pool.default.name
  config {
    subject_config {
      subject {
        country_code        = "us"
        organization        = "justinsweeney"
        organizational_unit = "solr"
        locality            = "boston"
        province            = "massachusetts"
        common_name         = "solr-ssl-certificate-authority"
      }
    }
    x509_config {
      ca_options {
        is_ca = true
      }
      key_usage {
        base_key_usage {
          cert_sign = true
          crl_sign  = true
        }
        extended_key_usage {
          server_auth = true
          client_auth = true
        }
      }
    }
  }
  type = "SELF_SIGNED"
  key_spec {
    algorithm = "RSA_PKCS1_4096_SHA256"
  }

  // Disable CA deletion related safe checks for easier cleanup.
  deletion_protection                    = false
  skip_grace_period                      = true
  ignore_active_certificates_on_deletion = true
}