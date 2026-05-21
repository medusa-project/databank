FROM ruby:3.3.6

ARG rails_env=test
ARG NODE_MAJOR=20
ENV RAILS_ENV=${rails_env}
ENV RAILS_LOG_TO_STDOUT=true

RUN apt-get update --allow-releaseinfo-change \
	&& apt-get install -y --no-install-recommends curl gnupg ca-certificates \
	&& mkdir -p /etc/apt/keyrings \
	&& curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
	&& echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
	&& curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/yarn.gpg \
	&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
	&& apt-get update --allow-releaseinfo-change \
	&& apt-get install -y --no-install-recommends \
	build-essential \
	ripgrep \
	autoconf \
	automake \
	libtool \
	pkg-config \
	systemd \
	nodejs \
	libmemcached-dev \
	libmagic-dev \
	yarn \
	postgresql-client \
	libpq-dev \
	memcached \
	emacs-nox \
	chromium \
	chromium-driver \
	libxml2-dev \
	libxslt1-dev \
	zlib1g-dev \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Ensure nokogiri uses system libraries to avoid Ruby 3.3.x build issues
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=true