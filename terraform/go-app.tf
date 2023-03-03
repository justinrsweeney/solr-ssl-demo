resource "kubectl_manifest" "go-app-deployment" {
  depends_on = [kubectl_manifest.google_cas_client_cert]
  yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: solr-ssl-demo-gke
spec:
  replicas: 1
  selector:
    matchLabels:
      app: solr-ssl-demo
  template:
    metadata:
      labels:
        app: solr-ssl-demo
    spec:
      containers:
        - name: solr-ssl-demo
          image: gcr.io/playground-377815/solr-ssl-demo:latest
          # This app listens on port 8080 for web traffic by default.
          ports:
            - containerPort: 8080
          env:
            - name: PORT
              value: "8080"
          volumeMounts:
            - name: go-client-cert
              mountPath: "/etc/go-client-cert"
              readOnly: true
      volumes:
        - name: go-client-cert
          secret:
            secretName: go-client-cert-tls
YAML
}