FROM ruby:3.3.6

ARG rails_env=test
ENV RAILS_ENV=${rails_env}
ENV RAILS_LOG_TO_STDOUT=true

RUN apt-get update --allow-releaseinfo-change \
	&& apt-get install -y --no-install-recommends curl gnupg \
	&& curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/yarn.gpg \
	&& echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
	&& apt-get update --allow-releaseinfo-change \
	&& apt-get install -y --no-install-recommends \
		build-essential \
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
		libxml2-dev \
		libxslt1-dev \
		zlib1g-dev \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Ensure nokogiri uses system libraries to avoid Ruby 3.3.x build issues
ENV NOKOGIRI_USE_SYSTEM_LIBRARIES=true