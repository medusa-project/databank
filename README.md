[![DOI](https://zenodo.org/badge/12882/medusa-project/databank.svg)](https://zenodo.org/badge/latestdoi/12882/medusa-project/databank)

# Databank

Databank is the Ruby on Rails web application component of Illinois Data Bank, which is a public access repository for research data from the University of Illinois Urbana-Champaign.

## Getting Started

### Prerequisites

- Ruby (version 3.3.6)
- Rails (version 7.2.3)
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

### Using the Databank Dev Container with databank-2

If you keep `databank` and `databank-2` as sibling folders in one parent directory, you can run both from the dev container configuration in this repository.

1. Open a multi-root workspace where `databank` is the first folder and `databank-2` is the second folder.
2. In VS Code, run **Dev Containers: Reopen in Container**.
3. VS Code will use `.devcontainer/devcontainer.json` from `databank` and start the compose services defined for local development.

The provided workspace file `lib/tasks/databank.code-workspace` is an example that includes both repositories when they are laid out as siblings.

### Running the Application

Start the Rails server:

```sh
rails server
```

### Running Tests

Databank uses two test layers:

- Full regression testing (local/devcontainer): Docker-based RSpec and browser tests
- Lightweight CI checks (local and GitHub Actions): security and lint checks

To run the full RSpec suite in the current shell environment, use:

```
rspec
```

For local/devcontainer parity with production-like services, use:

```sh
./docker-test.sh
```

To run Playwright browser tests against a running application instance:

```sh
npm run playwright:test
```

### Migration Bundle Export (Legacy Databank)

Legacy databank can export migration bundles for databank-2 import.

```sh
bin/rails migration:legacy:export_bundle
```

Optional params:

- `OUTPUT_ROOT=/path/to/output_dir` (default: `tmp/migration_exports`)
- `SINCE=2026-01-01T00:00:00Z` (export records with `updated_at >= SINCE`)
- `UNTIL=2026-02-01T00:00:00Z` (export records with `updated_at < UNTIL`)
- `INCLUDE_TESTS=true` (default excludes test datasets)

If you need test datasets available after migration (for internal testing or
server-side exploration), run production export with `INCLUDE_TESTS=true`.

Each run writes three artifacts in a timestamped directory:

- `legacy_datasets.ndjson` (one dataset record per line)
- `legacy_datasets.ndjson.sha256` (SHA256 checksum sidecar)
- `manifest.json` (record count, checksum, run metadata)

The NDJSON payload includes sensitive depositor/owner fields intended for secure
migration into databank-2.

### Sequential Local Migration Handoff (One Repo at a Time)

For local migration rehearsal, run `databank` and `databank-2` work in sequence.
Do not run migration commands in both repos at the same time.

1. In `databank`, create deterministic seed datasets:

```sh
bin/rails testing:seed_migration_test_data RESET=true
```

2. In `databank`, export a flat test bundle for those seeded keys:

```sh
OUTPUT_ROOT=/tmp/databank_exports \
KEYS=TESTIDB-MIGRATE1,TESTIDB-MIGRATE2,TESTIDB-MIGRATE3 \
bin/rails migration:legacy:export_test_bundle
```

3. Stop working in `databank` and switch to `databank-2`.

4. In `databank-2`, run dry-run import first, then real import from the exported directory:

```sh
DIR=/tmp/databank_exports/dataset_flat_test_<timestamp> \
bin/rails migration:flat_bundle:import_from_dir DRY_RUN=true

DIR=/tmp/databank_exports/dataset_flat_test_<timestamp> \
bin/rails migration:flat_bundle:import_from_dir
```

5. In `databank-2`, run reconciliation/smoke checks:

```sh
bin/rails cutover:reconcile
bin/rails cutover:smoke
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

To run Playwright tests locally against a running application instance:

```
npm run playwright:test
```

Playwright expects the Rails application to already be running and reachable at `http://127.0.0.1:3000` unless `PLAYWRIGHT_BASE_URL` is set.

To open the Playwright HTML report from the dev container with the forwarded report port:

```
npm run playwright:report
```

The Playwright report server is configured to bind to `0.0.0.0:9323`, which matches the forwarded dev container port.

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
EDITOR=emacs bundle exec rails credentials:edit --environment demo
```

##### Test identities and seed data

In the demo and production instances, identities from the UIUC community (using the Shibboleth strategy omniauth-shibboleth). Development and Test instances use the OmniAuth developer strategy in a way that is not used in demo or production.

A few seed datasets are populated by the docker-run script.

#### GitHub Actions

For developers in Library IT at University of Illinois Urbana-Champaign authorized to commit to the code repository in GitHub, lightweight CI checks run on pull requests and commits to `main`:

- `scan_ruby` (Brakeman and bundler-audit)
- `scan_js` (npm audit)
- `lint` (RuboCop)

These checks are intentionally lightweight to reduce remote CI build load.

Run the same lightweight checks locally before pushing:

```sh
bin/ci
```

Full regression testing remains local/devcontainer based:

- `./docker-test.sh` for RSpec-based integration testing
- `npm run playwright:test` for Playwright browser testing (against a running app)

#### Pre-Push Checklist

Run this checklist before pushing a branch. It is ordered from fastest checks to slower checks.

1. Install/update dependencies when needed.

```sh
bundle install
npm ci
```

2. Run lightweight CI parity checks (matches required GitHub Actions checks `scan_ruby`, `scan_js`, and `lint`).

```sh
bin/ci
```

`bin/ci` covers the required PR checks as follows:

- `scan_ruby`: Brakeman + bundler-audit
- `scan_js`: npm audit
- `lint`: RuboCop

3. Run full regression tests locally for behavior confidence.

```sh
./docker-test.sh
```

4. Run browser regression tests when UI flows changed.

```sh
npm run playwright:test
```
