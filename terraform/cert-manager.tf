module "cert_manager" {
  depends_on = [google_container_node_pool.primary_nodes]
  source        = "terraform-iaac/cert-manager/kubernetes"
  cluster_issuer_email                   = "justin.sweeney77@gmail.com"
  cluster_issuer_create = false
}

resource "helm_release" "google-cas-issuer" {
  depends_on = [module.cert_manager]
  name       = "cert-manager-google-cas-issuer"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager-google-cas-issuer"
  namespace = "cert-manager"
  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = "sa-google-cas-issuer@${var.project_id}.iam.gserviceaccount.com"
  }
}

resource "google_service_account" "sa-google-cas-issuer" {
  account_id   = "sa-google-cas-issuer"
  display_name = "Google CAS Issuer Service Account"
}

resource "google_privateca_ca_pool_iam_binding" "binding" {
  ca_pool = google_privateca_ca_pool.default.id
  role = "roles/privateca.certificateRequester"
  members = [
    "serviceAccount:${google_service_account.sa-google-cas-issuer.email}",
  ]
}

resource "google_service_account_iam_binding" "cert-manager-wi-iam" {
  service_account_id = google_service_account.sa-google-cas-issuer.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[cert-manager/cert-manager-google-cas-issuer]",
  ]
}

resource "kubectl_manifest" "google_cas_issuer" {
  depends_on = [helm_release.google-cas-issuer]
  yaml_body = <<YAML
# googlecasclusterissuer-sample.yaml
apiVersion: cas-issuer.jetstack.io/v1beta1
kind: GoogleCASClusterIssuer
metadata:
  name: googlecasclusterissuer
spec:
  project: ${var.project_id}
  location: us-central1
  caPoolId: ${google_privateca_ca_pool.default.name}
YAML
}

resource "kubectl_manifest" "google_cas_client_cert" {
  depends_on = [kubectl_manifest.google_cas_issuer]
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: go-client-certificate
  namespace: default
spec:
  # The secret name to store the signed certificate
  secretName: go-client-cert-tls
  # Common Name
  dnsNames:
  - cert-manager.io.go-client
  # Duration of the certificate
  duration: 24h
  # Renew 8 hours before the certificate expiration
  renewBefore: 8h
  # Important: Ensure the issuerRef is set to the issuer or cluster issuer configured earlier
  issuerRef:
    group: cas-issuer.jetstack.io
    kind: GoogleCASClusterIssuer
    name: googlecasclusterissuer
YAML
}