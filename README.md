# Docker Microservices

Generic template for an integrated local development environment using nginx
as a reverse-proxy server; requires SSL cert.

## Secret Management

A local instance of Consul by HashiCorp is provided and available at `consul.<yourdomain>`

## Database/Cache Support

Service set-up provided for postgres, mysql, redis, and memcached.
Templating for migration and seed data containers are provided in the docker-compose

## How to Add a Service to the Stack

TODO

## Building Proxy Image

The proxy container is responsible for serving static content, and requires webpack bundles, etc.
added to the proxy image. TODO: Dockerfile in `nginx/`; steps to build proxy image.

## Local Development Overrides

Services in default docker-compose can be overridden by adding overrides configuration to the
overrides directory. This can allow bind mounting local code bases into container volumes for quick local development of frontends and apis. - TODO

## Contract Testing Verifcation using Pact.io

TODO