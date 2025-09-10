FROM ubuntu:22.04
FROM ruby:3.3.6

ARG rails_env=test
ENV RAILS_ENV=test
ENV RAILS_LOG_TO_STDOUT=true

RUN apt-get update && apt-get install -y \
    systemd \
    nodejs \
    libmemcached-dev \
    libmagic-dev \
    yarn \
    postgresql-client \
    memcached \
    emacs-nox