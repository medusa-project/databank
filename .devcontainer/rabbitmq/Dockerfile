# The parent Dockerfile has a lot of layers which may lead to "max depth
# exceeded" messages. This version is known to work.
FROM rabbitmq:3.8.5

ENV RABBITMQ_DEFAULT_USER=databank
ENV RABBITMQ_DEFAULT_PASS=password

# Copy the configuration files
ADD .devcontainer/rabbitmq/rabbitmq.conf /etc/rabbitmq/
ADD .devcontainer/rabbitmq/definitions.json /etc/rabbitmq/

RUN chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.conf /etc/rabbitmq/definitions.json

RUN rabbitmq-plugins enable rabbitmq_management