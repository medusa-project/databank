# invocation
# docker build -t sunspot .
# docker run --name sunspot -p 8984:8983 -d sunspot
# ENV=test
# curl "http://localhost:8984/solr/admin/cores?action=CREATE&name=$ENV&instanceDir=$ENV"

FROM solr:6

USER root

COPY .devcontainer/sunspot/*.* ./

# test env
RUN mkdir -p server/solr/test/conf
RUN cp _rest_managed.json server/solr/test/conf/
RUN cp admin-extra.html server/solr/test/conf/
RUN cp currency.xml server/solr/test/conf/
RUN cp elevate.xml server/solr/test/conf/
RUN cp mapping-ISOLatin1Accent.txt server/solr/test/conf/
RUN cp protwords.txt server/solr/test/conf/
RUN cp schema.xml server/solr/test/conf/
RUN cp scripts.conf server/solr/test/conf/
RUN cp solrconfig.xml server/solr/test/conf/
RUN cp spellings.txt server/solr/test/conf/
RUN cp synonyms.txt server/solr/test/conf/

# development env
RUN mkdir -p server/solr/development/conf
RUN cp _rest_managed.json server/solr/development/conf/
RUN cp admin-extra.html server/solr/development/conf/
RUN cp currency.xml server/solr/development/conf/
RUN cp elevate.xml server/solr/development/conf/
RUN cp mapping-ISOLatin1Accent.txt server/solr/development/conf/
RUN cp protwords.txt server/solr/development/conf/
RUN cp schema.xml server/solr/development/conf/
RUN cp scripts.conf server/solr/development/conf/
RUN cp solrconfig.xml server/solr/development/conf/
RUN cp spellings.txt server/solr/development/conf/
RUN cp synonyms.txt server/solr/development/conf/

RUN chown -R solr server/solr

USER solr