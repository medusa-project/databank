
FROM solr:8.11.1@sha256:9da258c26ec3cd05bdfd790ee6567bd5db2a161a8a7fdf1694a6a3dce97cdd4e

USER root

# Set environment variable
ENV VERBOSE=yes

RUN mkdir -p /var/solr/data/configsets/testset/conf


# Copy conf directory to Solr core directory where Solr expects it
COPY conf /var/solr/data/test/conf

# Change ownership of the copied files to the solr user
RUN chown -R solr /var/solr/data/test/conf
USER solr

