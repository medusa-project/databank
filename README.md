[![DOI](https://zenodo.org/badge/12882/medusa-project/databank.svg)](https://zenodo.org/badge/latestdoi/12882/medusa-project/databank)
# Databank

Databank is the Ruby on Rails web application component of Illinois Data Bank, which is a public access repository for research data from the University of Illinois Urbana-Champaign.

## Getting Started

### Prerequisites

- Ruby (version 3.3.6)
- Rails (version 7.2.2)
- PostgreSQL
- Solr

### Integration
This application is one component of a set of interconnected services and resources. Details of integration are internally documented. These are mentioned here to be clear that this application does not stand alone. It requires accounts and connection to many other systems.

#### Managed by Library IT at University of Illinois at Urbana-Champaign
Medusa Collection Registry  
RabbitMQ message queues  
AWS Simple Message System queues  
Cantaloupe image server  
Medusa Downloader  
Illinois Data Bank Archive Extractor

#### Managed at campus-level by University of Illinois at Urbana-Champaign
Shibboleth  
Illinois Experts 

#### External integrations
DataCite  
ORCiD

### Installation (after integrations are configured)

1. Clone the repository:

    ```sh
    git clone https://github.com/medusa-project/databank.git
    cd databank
    ```

2. Install the required gems:

    ```sh
    bundle install
    ```

3. Set up the database:

    ```sh
    rails db:create
    rails db:migrate
    rails db:seed
    ```

### Running the Application

Start the Rails server:

```sh
rails server
```

### Running Tests
To run the test suite, use the following command:
```
rspec
```

### Deployment
Authorized members of Library IT at the University of Illinois Urbana Champaign can review internal documentation.

For more general deployment instructions, please refer to the [Rails deployment guide](https://guides.rubyonrails.org/deployment.html).

## License

This project is licensed under the University of Illinois/NCSA Open Source License

### Local Development and Local Testing with Docker
 
#### Launching with Docker
The source code repository for databank contains Docker-related files to use for a local development or testing environment.

Docker must be installed and configured on the local machine.

Copy development and test versions of config files from the automated test config files. These do not need to be modified to work, but they can be modified for any local considerations.

From the application root directory:
```
cd config
cp amqp-ci.yml amqp-test.yml
cp amqp-ci.yml amqp-development.yml
cp databank-ci.yml databank-development.yml
cp databank-ci.yml databank-test.yml
cp medusa-storage-ci.yml medusa-storage-development.yml
cp medusa-storage-ci.yml medusa-storage-test.yml
```
To run a development instance, from the root of the project:
```
./docker-run.sh
```
It takes a few minutes, with some pauses. When prompted, you can interact with the development instance at localhost:3000.

#### Running Tests Locally
To locally run the automated tests, from the root of the project:
```
./docker-test.sh
```
To locally run an environment for manually running test locally (handy for developing and refining tests):
```
./docker-local-test.sh
```
For both the development instance and the local test instance, launch an interactive terminal session to interact with running instance to run rake tasks or rails console.

##### Interactive shell prompt
A development or test instance must be running before initiating an interactive shell prompt with the app container.

Once the instance is running (using a script as described above), from a terminal screen list the docker containers.
```
docker ps
```
If the app container (for example: databank-development) has an identity of abc123, then to establish an interactive session with the container:
```
docker exec -it abc123 sh
```
This prompt can then be used for scaffold generation, database migration, or any other tasks that require an interactive shell.

##### Editing credentials files
Launch a development application instance using the script described above to edit the credentials files.

Once the instance is running, from a terminal screen invoke docker ps to list the containers. If the databank-development container has an identity of abc123, then to edit a credentials file first establish an interactive session with the container:
```
docker exec -it abc123 sh
```
Then, from the interactive shell prompt, specify emacs as the editor (which is installed as part of the docker script) and launch the editor for the credentials file:
```
EDITOR=emacs bundle exec rails credentials:edit --environment demo-rocky
```
##### Test identities and seed data
In the demo and production instances, identities from the UIUC community (using the Shibboleth strategy omniauth-shibboleth). Development and Test instances use the OmniAuth developer strategy in a way that is not used in demo or production.

A few seed datasets are populated by the docker-run script.

#### GitHub Actions
For developers in Library IT at University of Illinois Urbana-Champaign authorized to commit to the code repository in GitHub, the rspec tests will be automatically run on commit to main branch or on a pull request.
