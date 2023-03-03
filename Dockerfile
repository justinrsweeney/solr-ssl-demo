FROM golang:1.19-bullseye

WORKDIR /app

COPY src/* ./

RUN go mod download

RUN env GOOS=linux GOARCH=amd64 go build -o /solr-ssl-demo

EXPOSE 8080

ENTRYPOINT [ "/solr-ssl-demo" ]