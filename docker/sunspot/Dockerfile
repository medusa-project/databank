
FROM solr:8.11.1@sha256:9da258c26ec3cd05bdfd790ee6567bd5db2a161a8a7fdf1694a6a3dce97cdd4e

USER root

# Set environment variable
ENV VERBOSE=yes

RUN mkdir -p /var/solr/data/configsets/testset/conf


# Copy conf directory to Solr core directory where Solr expects it
COPY conf /var/solr/data/test/conf


# Ensure /var/solr/data is owned by solr user for core creation
RUN mkdir -p /var/solr/data/test && chown -R solr:solr /var/solr/data
USER solr

