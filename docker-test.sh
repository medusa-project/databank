#!/bin/sh

docker compose rm -f databank-test
docker compose -f docker-compose.yml -f docker-compose.test.yml up \
    --build --exit-code-from databank-test
