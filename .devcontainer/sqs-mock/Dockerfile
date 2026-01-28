# invocation
# docker build -t sqs-mock .
# docker run --name sqs-mock -p 9324:9324 -d sqs-mock

FROM softwaremill/elasticmq-native:latest

# Copy the configuration files
COPY .devcontainer/sqs-mock/elasticmq.conf /opt/elasticmq.conf
