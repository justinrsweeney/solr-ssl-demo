package main

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"github.com/gorilla/mux"
	"net/http"
	"os"
)

var (
	SolrServers = []string{"solr-vm-0", "solr-vm-1"}
	SolrPort   = 8983
	LastUsedServerIndex = 0
)

var client *http.Client

func main() {
	r := mux.NewRouter()

	caCert, _ := os.ReadFile("/etc/go-client-cert/ca.crt")
	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	cert, _ := tls.LoadX509KeyPair("/etc/go-client-cert/tls.crt", "/etc/go-client-cert/tls.key")

	client = &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				RootCAs:      caCertPool,
				Certificates: []tls.Certificate{cert},
			},
		},
	}

	// The "HandleFunc" method accepts a path and a function as arguments
	// (Yes, we can pass functions as arguments, and even treat them like variables in Go)
	// However, the handler function has to have the appropriate signature (as described by the "handler" function below)
	r.HandleFunc("/createCollection", createCollectionHandler).Methods("GET")
	r.HandleFunc("/query", queryHandler).Methods("GET")

	// After defining our server, we finally "listen and serve" on port 8080
	// The second argument is the handler, which we will come to later on, but for now it is left as nil,
	// and the handler defined above (in "HandleFunc") is used
	http.ListenAndServe(":8080", r)
}

// "handler" is our handler function. It has to follow the function signature of a ResponseWriter and Request type
// as the arguments.
func createCollectionHandler(w http.ResponseWriter, r *http.Request) {
	collectionName := r.URL.Query().Get("name")
	requestURL := fmt.Sprintf("https://%s:%d/solr/admin/collections?action=CREATE&name=%s&numShards=%d", getHostRoundRobin(), SolrPort, collectionName, 2)
	res, err := client.Get(requestURL)
	if err != nil {
		fmt.Printf("error making http request: %s\n", err)
	}

	fmt.Printf("client: got response!\n")
	fmt.Printf("client: status code: %d\n", res.StatusCode)
}

func queryHandler(w http.ResponseWriter, r *http.Request) {
	collectionName := r.URL.Query().Get("name")
	queryString := r.URL.Query().Get("q")
	requestURL := fmt.Sprintf("https://%s:%d/solr/%s/select?q=%s", getHostRoundRobin(), SolrPort, collectionName, queryString)
	res, err := client.Get(requestURL)
	if err != nil {
		fmt.Printf("error making http request: %s\n", err)
	}

	fmt.Printf("client: got response!\n")
	fmt.Printf("client: status code: %d\n", res.StatusCode)
	fmt.Printf("client: response: %d\n", res.Body)
}

func getHostRoundRobin() string {
	LastUsedServerIndex = (LastUsedServerIndex+1) % 2
	return SolrServers[LastUsedServerIndex]
}
