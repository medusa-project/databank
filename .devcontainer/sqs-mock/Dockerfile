# invocation
# docker build -t sqs-mock .
# docker run --name sqs-mock -p 9324:9324 -d sqs-mock

FROM s12v/elasticmq

# Copy the configuration files
COPY .devcontainer/sqs-mock/elasticmq.conf /etc/elasticmq/
