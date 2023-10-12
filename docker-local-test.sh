#!/bin/sh

docker compose \
    -f docker-compose.yml \
    -f docker-compose.local-test.yml \
    up \
    --build \
    --exit-code-from databank-local-test
