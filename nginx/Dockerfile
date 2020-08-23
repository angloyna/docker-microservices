FROM nginx:mainline-alpine-perl

COPY data /data

COPY config /etc/nginx/nginx.conf
COPY proxy_params host-* static* /etc/nginx/
COPY ssl /etc/nginx/ssl
