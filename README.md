# VOLT electronics ecommerce

VOLT is a Flask + SQLite electronics store with 12 fictional sample products, original device illustrations, responsive layouts, category/brand/price/stock filters, sorting, product detail URLs, specification comparison, account-based wishlists, registration/login, persistent carts, atomic stock-checked checkout, order history, inventory and fulfillment administration. Prices are integer paise. Checkout is explicitly a demo and collects no payment.

The original gift catalog is archived by an idempotent schema/catalog migration. Existing user accounts and historical order-item snapshots are preserved. Legacy gift carts are cleared as their products are archived. New installs receive only electronics. `catalog.py` defines the sample products; real payment, shipping and manufacturer services are not connected.

## Run locally (PowerShell)

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r requirements.txt
# Set a stable, random session key for persistent sessions across restarts.
$env:SECRET_KEY = 'replace-with-a-long-random-secret'
.\.venv\Scripts\python app.py
```

Open http://127.0.0.1:8000. The database is created at `data/shop.db`; demo products are seeded only when the catalog is empty. Set `ADMIN_EMAIL` and `ADMIN_PASSWORD` before startup to create an admin account. Existing accounts are not silently promoted. Keep these values out of Git and recordings.

```powershell
.\.venv\Scripts\python -m unittest discover -s tests -v
node --check static/app.js
.\.venv\Scripts\python scripts/backup.py data/shop.db backups/shop-snapshot.db
```

Tests cover checkout totals calculated by the server, stock deduction, cart clearing, repeat checkout rejection, CSRF, admin authorization, user order isolation, and invalid quantities.

## Azure account and DevOps connection

Requested identity: `giftzee.online@gmail.com` (from the supplied Azure Portal screenshot). The initially cached CLI identity belongs to another directory; do not deploy using that identity. Sign in with `az login --use-device-code`, then verify the user and subscription with `az account show`. The screenshot does not establish an Azure DevOps organization URL. Obtain the correct `https://dev.azure.com/<organization>` URL and project before creating or pushing resources.

```powershell
az devops configure --defaults organization=https://dev.azure.com/YOUR_ORGANIZATION project=VoltElectronics
az repos create --name volt-electronics
# Use the returned remoteUrl; do not embed a PAT in the remote.
git add .
git commit -m "Build VoltElectronics store and Azure infrastructure pipelines"
git branch -M main
git remote add origin RETURNED_REMOTE_URL
git push -u origin main
az pipelines create --name volt-electronics-ci-cd --repository volt-electronics --repository-type tfsgit --branch main --yml-path azure-pipelines.yml --skip-first-run
```

Create the project first if needed using `az devops project create --name VoltElectronics --visibility private`. Do not place credentials in chat or source files. Azure Repos PR validation uses a **branch build-validation policy**; the YAML `pr` stanza alone does not enable Azure Repos pull-request validation.

## Remote Terraform backend

Terraform 1.9.8 or newer within 1.x is required. Provider lock files are included. Run from the repository root after signing in to the intended subscription:

```powershell
.\scripts\bootstrap.ps1 -SubscriptionId YOUR_SUBSCRIPTION_ID -StorageName UNIQUE_LOWERCASE_STORAGE_NAME -Location centralindia
```

The bootstrap creates a separate resource group and storage account, enables blob versioning and soft deletion, disables public blobs/shared keys, grants the current identity Blob Data Contributor, and creates the `tfstate` container using Entra authentication. It initializes the app backend and migrates bootstrap state into its own remote key. RBAC propagation may require retrying the container operation. Preserve bootstrap local state until migration succeeds. The storage account has `prevent_destroy`; do not remove that protection casually.

App state key: `volt-electronics/app.tfstate`. Bootstrap state key: `volt-electronics/bootstrap.tfstate`. Azure Blob backend provides state locking. State includes the generated session secret: restrict backend access and keep plans/state out of source control.

## CI and CD

The full pipeline walkthrough and setup command are in [docs/pipeline.md](docs/pipeline.md). The stages are Validate â†’ Test â†’ Build â†’ Infrastructure â†’ Release â†’ Verify.

Create an Azure Resource Manager service connection with **workload identity federation**, scoped to the intended subscription/resource groups. It needs permission to manage the app resources and **Storage Blob Data Contributor** on the backend storage account. Authorize this pipeline specifically. Configure the `volt-electronics-production` environment, its exclusive-lock check and, if desired, approval/checks.

Set the following pipeline variables in Azure DevOps:

| Variable | Value |
| --- | --- |
| azureServiceConnection | Name of the federated Azure service connection |
| subscriptionId | VoltElectronics Azure subscription UUID |
| appName | Globally unique web app name, e.g. volt-electronics-shop-UNIQUE |
| azureLocation | centralindia or your chosen supported region |
| stateResourceGroup | volt-electronics-tfstate-rg |
| stateStorageAccount | Name produced by bootstrap |

CI validates source and both Terraform configurations, publishes JUnit and coverage reports, and builds a ZIP with commit metadata and SHA256. CD is enabled by the `deployAzure` run parameter and runs only for main, uses a federated token, initializes remote state, saves and applies an exact plan, verifies and deploys the artifact, and checks health, catalog, assets and deployed commit. Do not run an untrusted branch with the production service connection.

## Hosting and operational limits

Terraform configures a Linux B1 App Service with Python 3.12, HTTPS, managed identity, health checks, one worker, a stable generated session secret, and SQLite at `/home/data/volt-electronics.db`. App Service keeps data under `/home` persistent across application deployments. See [Microsoft App Service storage guidance](https://learn.microsoft.com/en-us/azure/app-service/configure-custom-container#use-persistent-shared-storage).

This is a single-instance demonstration architecture. SQLite file locking on shared cloud filesystems needs workload-specific validation; do not scale this deployment horizontally or use deployment slots against the same database. For a production SQLite deployment prefer a single VM with a managed local disk; alternatively migrate to a managed relational database. No real payments, tax calculation, shipping integration, password recovery, authentication throttling, automated backup schedule, or production monitoring/alerts are configured. B1 and storage incur Azure charges when applied. `giftzee.online` is an account identifier here; custom-domain/DNS ownership has not been verified or configured.

Use the SQLite backup script for consistent snapshots; store encrypted backups outside the app host and validate restores before launch. Changing or destroying the app resource may lose its home data; back up before such changes.

## Recording

`recordings/process.mkv` records the desktop from shortly after the initial workspace inspection. A finalized MP4 is produced when the work session is paused. Recordings are excluded from Git. Terminal operations run in the background, so the video shows the desktop/chat progress rather than a visible terminal for every command. Never type secrets visibly while recording.
