#!/bin/bash

dname=$(dirname "$(readlink -f "$0")")
source "$dname/config"
cd $dname

#Making dirs and files

mkdir "$dname/certs"
mkdir "$dname/etc"

touch "$dname/etc/nginx.conf"
touch "$dname/docker-compose.yml"

echo "server {
        listen 443 ssl;
        ssl on;
        ssl_certificate /etc/ssl/certs/web.crt;
        ssl_certificate_key /etc/ssl/certs/web.key;
        location / {
                proxy_pass http://apache;
}
}" > $dname/etc/nginx.conf

echo "version: '2'
services:
  nginx:
    image: $NGINX_IMAGE
    ports:
     - "$NGINX_PORT:443"
    volumes:
     - $dname/etc:/etc/nginx/conf.d
     - $dname/certs:/etc/ssl/certs
     - $NGINX_LOG_DIR:/var/log/nginx
  apache:
    image: $APACHE_IMAGE" > $dname/docker-compose.yml

#Making certificates

openssl genrsa -out $dname/certs/root.key 2048
openssl req -x509 -new -key $dname/certs/root.key -days 365 -out $dname/certs/root.crt -subj '/C=UA/ST=KharkivskaOblast/L=Kharkiv/O=KhNURE/OU=IMI/CN=rootCA'

openssl genrsa -out $dname/certs/web.key 2048
openssl req -new -key $dname/certs/web.key -nodes -out $dname/certs/web.csr -subj "/C=UA/ST=KharkivskaOblast/L=Karkiv/O=KhNURE/OU=IMI/CN=$(hostname -f)"

openssl x509 -req -extfile <(printf "subjectAltName=IP:${EXTERNAL_IP},DNS:${HOST_NAME}") -days 365 -in $dname/certs/web.csr -CA $dname/certs/root.crt -CAkey $dname/certs/root.key -CAcreateserial -out $dname/certs/web.crt

cat $dname/certs/root.crt >> $dname/certs/web.crt

#Installing docker-ce and docker-compose

apt-get update
apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install docker-ce -y
apt-get install docker-compose -y

docker-compose up -d

