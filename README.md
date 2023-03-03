# Solr SSL Demo Application

This application provides a demo of setting up Solr mTLS using Google Certificate
Authority Service to create certificates.

This also includes a sample Go client application that will run in GKE and use cert-manager
with Google CAS to connect and authenticate to Solr.

The steps below will get you set up from scratch.

## Terraform - Initialize GCR Registry

First create the GCR Registry:
1. `cd terraform`
2. `terraform init`
3. `terraform plan --target google_container_registry.registry`
4. `terraform apply --target google_container_registry.registry`

## Build and Push Go App Image
1. `docker build -t gcr.io/[PROJECT-ID]/solr-ssl-demo .`
2. `docker push gcr.io/[PROJECT-ID]/solr-ssl-demo`

## Terraform - Remaining Setup

Apply all other Terraform, this can be rerun as changes are made:
1. `cd terraform`
2. `terraform plan`
3. `terraform apply`

## Access the App
1. `gcloud container clusters get-credentials [PROJECT-ID]-gke --region us-central1-a --project [PROJECT-ID]`
2. `kubectl port-forward deployment/solr-ssl-demo-gke 8080`
3. `curl http://localhost:8080`
