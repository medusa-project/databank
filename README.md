[![DOI](https://zenodo.org/badge/12882/medusa-project/databank.svg)](https://zenodo.org/badge/latestdoi/12882/medusa-project/databank)

# Databank

Databank is the Ruby on Rails web application component of Illinois Data Bank, which is a public access repository for research data from the University of Illinois Urbana-Champaign.

## Getting Started

### Prerequisites

- Ruby (version 3.3.6)
- Rails (version 8.0.5.2 or a later 8.0.x security release)
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

   Keep `io-like` on the 0.3.x series: the current `medusa_storage`
   dependency requires its module-based API. Version 0.4 changes `IO::Like`
   to a class and prevents application boot, including deployment asset
   precompilation.

   Rails must be at least 8.0.5.2 to include the security fixes for Active
   Storage and the other Rails components. The application retains its
   existing Rails 7.1 framework defaults to avoid unrelated behavior changes.

   Keep `json` below version 3 while using Rails 8.0. Its JSON encoder passes
   `quirks_mode`, which JSON 3 rejects. This also breaks Tus S3 upload creation
   when it serializes upload metadata.

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

### Google Drive import (curator pilot)

The Google Drive control remains inside the curator-only block. The backend
also requires dataset management permission; a depositor cannot invoke it
directly. Imports are independent copies of one ordinary file, up to
50,000,000,000 bytes (50 GB). Google documents, folders, shortcuts, Shared Drives,
empty files, and duplicate dataset filenames are rejected.
Only one import may be queued or in progress per dataset; wait for it to
finish or cancel it before starting another.
Import status changes are announced separately from byte-progress updates.
Background polling errors do not move keyboard focus, and focus is restored
when a focused import control disappears. The confirmation dialog describes
the selected filename and size; authorization opens in a separate window.

Before deploying:

1. Enable Google Drive API and Google Picker API in the same Google Cloud
   project. Configure Google Auth platform branding, an External audience,
   test users while in Testing, and only the
   `https://www.googleapis.com/auth/drive.file` scope.
2. Create a Web application OAuth client. Register the application origin
   (`https://<host>`) and exact redirect URI
   (`https://<host>/integrations/google_drive/callback`). Authorization uses
   a popup so that unsaved dataset form edits are not discarded.
3. Configure the environment's Rails credentials under `google`:
   `api_key`, `client_id`, `client_secret`, and `project_number`. The project
   number is numeric and is not the project ID (`databank-integration`).
   Do not commit decrypted credentials. Restrict the Picker key to the
   Picker API and website origins using Google's current
   [Picker setup guidance](https://developers.google.com/workspace/drive/picker/guides/web-picker).
4. Run `bundle install` and `bin/rails db:migrate`, precompile assets, and
   restart the application and delayed-job workers. Workers must consume
   the `google_drive` queue (workers without queue filtering already do).
5. Google Drive imports to S3-backed draft storage stream 8 MiB Drive ranges
   directly into resumable S3 multipart uploads, using one range in memory
   rather than staging the full file on local disk. Progress and uploaded S3
   parts are persisted so a worker can resume after interruption. Failed and
   cancelled imports abort their multipart uploads. Configure an S3 lifecycle
   rule to abort incomplete multipart uploads after one day as protection
   against abrupt worker or host termination.
   Filesystem-backed draft storage still stages a full copy in the private
   `google.staging_dir` (if configured), `<storage_tmpdir>/google-drive-imports`,
   or Rails' `tmp` directory. Only one cloud import (Drive or Box) runs at a time across all
   workers; others wait in the queue. Filesystem staging checks for room for
   the remaining file plus a 10 GB reserve and waits if needed. Imports still
   waiting when their authorization expires (24 hours) are failed by
   `google_drive:cleanup`. Each job attempt permits up to three hours and
   three attempts. Ensure the global worker lock timeout is longer than this.
6. Schedule `bin/rails google_drive:cleanup` hourly in the deployment
   environment. This expires abandoned imports and removes temporary
   credentials after 24 hours. Successful, failed, and cancelled imports
   erase credentials as soon as no active imports need them.

Refresh credentials are encrypted using a key derived from Rails'
`secret_key_base`; it must remain stable and be shared by web and worker
processes. Only a short-lived access token reaches Picker, never the refresh
token or client secret. Token and authorization-code parameters are filtered
from Rails logs; configure reverse-proxy/access logs not to record the OAuth
callback query string. External OAuth apps in Testing generally have
seven-day refresh-token lifetimes for Drive scopes; production use also
requires the applicable Google verification and institutional approval.

Meaningful local checks use mocked Google responses:

```sh
bundle exec rspec spec/services/google_drive/client_spec.rb \
  spec/models/google_drive_connection_spec.rb \
  spec/jobs/google_drive_import_job_spec.rb \
  spec/controllers/google_drive_imports_controller_spec.rb
```

These check backend contracts, not actual Google consent or Picker behavior.
No live Google credentials are needed. Do not exercise production from
automated tests. For the production-only browser smoke test, use a curator
and a disposable draft dataset: authorize a test Google account, import a
small CSV, verify its downloaded bytes, revisit the page to check persistent
status, and test cancellation and duplicate-name rejection. Verify a file
shared by another account as well. Keep the pilot curator-only until the
live flow, browser accessibility, and production-like 50 GB transfers have
been qualified; a large-file success is not implied by the unit tests.

### Box import (curator pilot)

Box uses the same confirmation, persistent status, cancellation, Clear Notice,
and per-dataset active-import restriction as Google Drive. Users authorize their
own Box accounts; only ordinary downloadable files up to 50,000,000,000 bytes
are accepted. Folders, web links, and Box Notes are excluded. Imports require
S3-backed draft storage and use the shared resumable multipart transfer service
with 8 MiB buffers, SHA-1 source verification, and multipart ETag verification.
Box and Drive jobs share the single active-transfer slot; queued jobs wait
without consuming failure attempts.
Refresh credentials remain encrypted on the server for at most 24 hours; only
a downscoped `base_picker` token is returned to the browser. Box refresh tokens
rotate and are replaced under a database lock.
Box can omit the optional download-permission field; imports defer that check
to Box's authenticated content endpoint when it is absent. Explicit permission
denials and unavailable content are still rejected. Preview/authorization
failures are logged by the web process with the provider and action (for example,
`Box import preview failed`), before any background job is queued. Metadata
rejections also log only type, download-permission, availability, and item-status
flags, not filenames, tokens, or the full API response.

Before deploying:

1. Configure a Box OAuth 2.0 app with the **Read and write all files and folders
   stored in Box** (`root_readwrite`) scope. Box requires this scope for
   downloads; `root_readonly` permits browsing but is insufficient for importing
   file content. The server token consequently has write capability, but this
   integration only reads/downloads files and gives the browser a restricted
   `base_picker` token. Enterprise policy may require administrator approval.
   This is user OAuth, not JWT or Client Credentials Grant; the configured
   enterprise ID is not used for this flow. After changing scopes, save the Box
   app configuration, deploy the matching OAuth-request change, and authorize
   Box again from the dataset; existing tokens do not acquire the new scope.
2. Register the exact redirect URI `https://<host>/integrations/box/callback`
   for each deployment, and add the application origin to the Box app's CORS
   allowed origins for the browser-based Content Picker.
3. Configure `box.client_id` and `box.client_secret` in that environment's
   Rails credentials (referenced by `databank.yml`). Never expose the secret
   or refresh token in page content or logs.
4. Run `bin/rails db:migrate`, precompile assets, and restart web and delayed-job
   processes. Workers must consume the `box` queue (unfiltered workers do).
5. Schedule `bin/rails box:cleanup` hourly. Use an S3 lifecycle rule to abort
   incomplete multipart uploads after one day, as with Drive. Permit the
   worker to create, upload, complete, abort, read, and delete S3 objects.
6. Permit the pinned Box Content Picker JS/CSS from
   `https://cdn01.boxcdn.net/platform/elements/26.3.0/en-US/` and Box API access
   in any deployed Content Security Policy. The picker loads only on use.

Test on demo using a curator and a disposable draft: authorize Box, select a
small binary file, confirm its name and size, check downloaded bytes, then test
a larger file, cancellation, duplicate filenames, and returning to the page
during an import. Verify keyboard navigation, Escape/cancel behavior, and
screen-reader announcements in the real Box OAuth/Picker flow; automated tests
stub provider responses and do not certify Box's third-party UI accessibility.

### Copying Public Datasets to Globus

```sh
RAILS_ENV=demo bundle exec rails globus:copy_datasets
```

The pinned `medusa_storage` dependency uses the deprecated S3 object streaming
API. The application overrides its multipart upload method in
`config/initializers/medusa_storage_s3.rb` to use `Aws::S3::TransferManager`
and put the upload stream in binary mode. This prevents Rails' UTF-8 internal
encoding from transcoding file bytes and preserves the existing multipart
ETag verification and metadata handling.

After deploying this fix, rerun the command on demo to validate the actual
storage endpoints. Already-present destination files are skipped by the task.

### Migration Bundle Export (Legacy Databank)

Legacy databank can export migration bundles for databank-2 import.
The Rails 8.0 upgrade preserves the existing export fields and NDJSON date
and timestamp representations.

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

Optional: seed additional realistic legacy-style values locally from the
old-style dataset bundle in `databank-2` (one-off helper, not an ongoing workflow):

```sh
bin/rails testing:seed_from_old_bundle_values \
   SOURCE_BUNDLE=/workspaces/databank-2/test_bundle/dataset_20260626T185934Z/legacy_datasets.ndjson \
   LIMIT=12 \
   KEY_PREFIX=LEGACYBUNDLE- \
   RESET=true
```

This imports sample dataset values and nested associations into local `databank`
records with prefixed keys.

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
