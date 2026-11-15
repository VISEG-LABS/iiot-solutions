# VISEG CONNECT infrastructure

Bicep source for the Azure resources used by the CONNECT application. Keep this directory current in **every work package** that changes resources, permissions, hosting, operational settings, or cost. If a package needs no infrastructure change, record that assessment in its completion evidence.

The CONNECT solution root is `src/acs-connect-client/`. Infrastructure lives beside its application projects in `src/acs-connect-client/Viseg.Connect.Infrastructure/`, with tests under `src/acs-connect-client/tests/`. Commands below run from the repository root.

Status: initial sandbox baseline; Bicep and sandbox parameters compile locally. No Azure deployment has been performed. Application publishing, migrations, SQL user bootstrap, and full runtime/Entra integration remain later work packages.

## Files and resources

- `main.bicep`: resource-group deployment of one Linux B1/B2 App Service instance, system-assigned identity, SQL Basic database (5 DTU, 2 GiB), Standard Key Vault and RSA protection key, LRS Blob storage and a private-access container, Log Analytics, workspace-based Application Insights, and scoped runtime RBAC assignments.
- `environments/sandbox.bicepparam`: demonstration settings in West Europe, using synthetic-data mode. The application implements this mode in its feature packages; the template alone does not create a runnable demo or synthetic CONNECT service.
- Bicep is the source of truth; do not maintain a separate hand-edited ARM JSON copy. The validation commands below discard generated JSON; deployment compiles the source templates directly.
- Keep source and source documentation self-contained, referring only to versioned repository files or public documentation. Do not depend on local ignored planning or verification files.

The sandbox uses public HTTPS endpoints and an Entra-only SQL server. Its `AllowAzureServices-SandboxOnly` SQL rule permits connections from Azure address space, including other customers' Azure workloads; identity authorization still applies. Replace it with explicit outbound-IP rules or reviewed private networking for production. No private endpoints, Redis, Azure SignalR service, NAT gateway, custom domain, deployment slot, Defender paid plan, or extra app instance is included.

## Two separate tenants

**Sign-in tenant:** the tenant containing the user-supplied Entra application registration. Store its non-secret `AzureAd` settings only in `src/acs-connect-client/Viseg.Connect.Web/appsettings.json` when WP-01 creates that app: `Instance`, `TenantId`, `ClientId`, `CallbackPath`, and any required domain/logout paths. Do not put copies in Bicep, `.bicepparam`, pipeline variables, App Service `AzureAd__*` settings, or another appsettings file. Configure the redirect URI in that registration after the web-app hostname is known. Keep single-tenant issuer validation pointed at this sign-in tenant even when Azure resources are elsewhere.

**Resource tenant:** the tenant attached to the Azure subscription where this template deploys. Log Azure CLI into this tenant. Managed identity, Key Vault tenant, SQL administrator group, SQL contained-user grants, Blob RBAC, and monitoring RBAC all belong here. Bicep uses `tenant().tenantId` for resource access; it never reads or creates the sign-in registration. The SQL administrator object ID is a resource-tenant administrative principal, not application registration configuration.

Sign-in does not grant a user access to the resource tenant. The server's managed identity accesses Azure resources; do not use an end user's sign-in token to open SQL/Key Vault/Blob. If confidential sign-in needs a certificate or credential, keep its value/material in Key Vault or local user-secrets, never plaintext appsettings; keep the registration's non-secret reference/settings in `appsettings.json`. Verify cross-tenant registration, redirect/logout behaviour, Admin role claims, and admission in WP-04. Cross-tenant OIDC federation for GitHub deployment is a separate resource-tenant setup in WP-03.

## Find the SQL administrator group object ID

`sqlAdministratorObjectId` is the Microsoft Entra **Object ID of the group that will administer the Azure SQL logical server**. The template sets `principalType: 'Group'`, so supply a group object ID from the **resource tenant**. It is separate from the website's Admin role, sign-in application/client ID, and tenant ID. The value is an identifier, not a secret; members of the selected group receive powerful SQL administrator access. The application itself later connects through its own managed identity with narrower database permissions.

In the Azure portal or Microsoft Entra admin center:

1. Switch to the directory containing the Azure subscription where the resources will be deployed.
2. Open **Microsoft Entra ID → Groups → All groups**.
3. Select an existing security group intended for SQL administration, or have a directory administrator create one, for example `CONNECT-SQL-Admins`.
4. Add the people who should administer SQL, including your resource-tenant user if you will perform database bootstrap.
5. Open the group's **Overview** page and copy **Object ID**.

Set the value in the PowerShell session used for parameter compilation/deployment:

```powershell
$env:VISEG_SQL_ADMIN_OBJECT_ID = 'COPIED-GROUP-OBJECT-ID'
```

Alternatively, after signing into the resource tenant, look up the group with Azure CLI:

```powershell
az login --tenant 'RESOURCE-TENANT-ID'
az ad group show --group 'CONNECT-SQL-Admins' --query '{name:displayName,objectId:id}' --output table
$env:VISEG_SQL_ADMIN_OBJECT_ID = az ad group show --group 'CONNECT-SQL-Admins' --query id --output tsv
if ($LASTEXITCODE -ne 0) { throw 'Could not resolve the resource-tenant SQL administrator group.' }
```

Use the exact object ID if group names are ambiguous. Directory permissions may restrict group creation, membership changes, or lookup; Azure subscription access alone does not grant those rights. Do not supply your user object ID to the current group-only template. `sandbox.bicepparam` reads the environment variable and passes it to `sqlAdministratorObjectId`; the default display label is descriptive and need not match the group's actual name.

References: [Configure an Azure SQL Microsoft Entra administrator](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-configure?view=azuresql), [manage Entra groups](https://learn.microsoft.com/en-us/entra/fundamentals/groups-view-azure-portal), and [Azure CLI group lookup](https://learn.microsoft.com/en-us/cli/azure/ad/group?view=azure-cli-latest#az-ad-group-show).

## Local validation

Prerequisites: current Azure CLI and Bicep CLI. Installing the CLI does not create cloud resources. From the repository root:

```powershell
az bicep install
$env:VISEG_SQL_ADMIN_OBJECT_ID = 'RESOURCE-TENANT-SQL-ADMIN-GROUP-OBJECT-ID'
az bicep build --file ./src/acs-connect-client/Viseg.Connect.Infrastructure/main.bicep --stdout | Out-Null
az bicep build-params --file ./src/acs-connect-client/Viseg.Connect.Infrastructure/environments/sandbox.bicepparam --stdout | Out-Null
```

Replace the object-ID placeholder with an actual group ID from the resource tenant before cloud validation. Local compilation may use a dummy GUID; it cannot prove permissions, service availability, or runtime support. Check the selected region's `DOTNETCORE|10.0` stack before deployment.

## Preview and deploy

The following commands contact Azure, and the create commands provision billable resources. They are operator instructions, not an instruction for an agent to run them automatically.

```powershell
$resourceTenantId = 'RESOURCE-TENANT-ID'
$subscriptionId = 'RESOURCE-SUBSCRIPTION-ID'
$resourceGroupName = 'rg-viseg-connect-sandbox'
$env:VISEG_SQL_ADMIN_OBJECT_ID = 'RESOURCE-TENANT-SQL-ADMIN-GROUP-OBJECT-ID'
az login --tenant $resourceTenantId
az account set --subscription $subscriptionId
az account show --query '{subscription:id,tenant:tenantId}' --output table
az webapp list-runtimes --os linux --output table

# Requires the resource group to exist. Creating it changes Azure state.
az group create --name $resourceGroupName --location westeurope
az deployment group validate --resource-group $resourceGroupName --parameters ./src/acs-connect-client/Viseg.Connect.Infrastructure/environments/sandbox.bicepparam
az deployment group what-if --resource-group $resourceGroupName --parameters ./src/acs-connect-client/Viseg.Connect.Infrastructure/environments/sandbox.bicepparam

# Run after reviewing the what-if and costs.
az deployment group create --name connect-sandbox --resource-group $resourceGroupName --parameters ./src/acs-connect-client/Viseg.Connect.Infrastructure/environments/sandbox.bicepparam
```

The deployment principal needs resource deployment and role-assignment rights at the relevant scope. Contributor alone cannot create the included role assignments. Required resource providers and regional subscription quotas must be available. Local build success is not cloud validation.

## After infrastructure deployment

1. Read deployment outputs for app URL, principal ID, SQL server, vault, and workspace. Give the sign-in registration owner the redirect/logout URLs; enter registration details only in the Web project's `appsettings.json`.
2. As the resource-tenant SQL administrator, create a contained database principal for the web app's managed identity using its object ID, then grant only the application permissions required by EF/runtime. Use a separate migration identity with schema-change rights. Bicep ARM RBAC does not itself create SQL users. The application cannot access SQL until this bootstrap is complete. Use a reviewed SQL script in this source folder when WP-03/04 implements it; do not copy identity credentials into SQL scripts.
3. Publish the application artifact and run migrations through the future controlled deployment workflow. The initial infrastructure does not deploy application binaries or seed users.
4. Confirm that runtime configuration binds `Secrets`, `DataProtection`, `ConnectionStrings:AppDatabase`, `Telemetry`, `Refresh`, `Dashboards`, and `Demo` settings supplied by the template. Configure Azure Monitor's credential explicitly with managed identity; local authentication is disabled on Application Insights. `APPLICATIONINSIGHTS_AUTHENTICATION_STRING` alone is not a substitute for configuring the selected .NET distribution.
5. Verify runtime Key Vault/Blob/monitoring permissions after RBAC propagation, encrypted persistent Data Protection, Entra login from the other tenant, and zero CONNECT traffic in synthetic demo mode. Ensure neither startup probes nor demo mode contacts CONNECT.
6. Add scoped GitHub OIDC deployment and migration identity definitions, cost budgets/alerts, resource diagnostics, and tested recovery controls as their work packages implement them.

## Cost and teardown

For a small West Europe demonstration, budget approximately **USD 20–25/month before tax**, based on November 2026 public rates and light usage. At 730 hours/month, Linux B1 at $0.018/hour and SQL Basic at $0.161/day total about $18.04/month before storage, vault operations, monitoring and network usage. Recheck region- and offer-specific rates with the [Azure pricing calculator](https://azure.microsoft.com/en-us/pricing/calculator/) and [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices). This estimate is not a quote or a production sizing guarantee; CONNECT subscriptions/usage are additional.

Stopping the web app does **not** stop charges for its App Service plan; SQL/storage/log charges also persist while resources remain. Delete only a deliberately selected sandbox resource group when finished, after reviewing its contents and preserving anything required. No automatic teardown command is provided or run. Key Vault purge protection means a deleted vault cannot immediately be purged/reused.

## Work-package completion rule

For each package: review the template/parameters/README; implement required resource/config/RBAC changes alongside code; compile and lint; record cloud what-if/validation results when cloud access is available; update the cost estimate if paid resources or meters change. Never let manual portal changes become the sole definition of required infrastructure. Entra registration changes remain explicit external setup documented here, with their details confined to Web `appsettings.json`.
