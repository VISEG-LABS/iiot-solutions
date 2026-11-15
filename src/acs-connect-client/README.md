# VISEG CONNECT client

.NET 10 Blazor Web App with static server rendering, selective Interactive Server components, Fluent UI v5, vendored Apache ECharts, and English/Swedish resources. The shell provides overview, explorer and dashboard **synthetic previews**. Live CONNECT transport, Entra sign-in/admission, database entities and dashboard persistence belong to subsequent delivery stages.

## Run locally

From this solution directory, with the SDK selected by `global.json` installed:

```powershell
dotnet restore Viseg.Connect.slnx --locked-mode
dotnet run --project Viseg.Connect.Web -- --urls http://localhost:5180
```

Open `http://localhost:5180`. The default demo makes no CONNECT, SQL, Key Vault or Azure Monitor calls. The server contains no live data endpoints or authentication implementation yet; do not treat this shell as a production access-controlled application. With `Demo:UseSyntheticData=false`, the pages show an unconfigured-live-access state and do not expose synthetic values.

Theme/language preferences use validated cookies and antiforgery-protected form posts. Both switches reload the page so the server renders the correct theme and culture immediately. Static assets use ASP.NET Core fingerprinting. Chart modules generate fixed UTC synthetic values locally, format in the browser time zone, and never send series arrays through the server circuit.

## Layout

- `Viseg.Connect.Core`: framework-independent domain validation and error codes.
- `Viseg.Connect.Cds`: transport boundary and request bounds; resource gateway/authenticated calls are not implemented yet.
- `Viseg.Connect.Data`: EF Core SQL context boundary; entities/migrations follow with access management.
- `Viseg.Connect.Web`: shell, preferences, localized resources, synthetic examples and runtime assets.
- `tests`: MSTest domain/resource checks and Playwright browser journeys.
- `build`: source/dependency/infrastructure validation scripts and the named transitive dependency policy.
- [Viseg.Connect.Infrastructure](Viseg.Connect.Infrastructure/README.md): Bicep resource source and operator instructions; review changes alongside each feature.

SDK/build/package configuration stays scoped to this solution. The Core project may not reference Web, Data, CDS or external packages. CI enforces dependency direction, central versions, package metadata policy, semantic colour usage, and vendored asset hashes. Only the listed Polly/OpenTelemetry transitive exceptions are allowed; direct dependencies remain Microsoft-authored. Metadata author checks are an automated policy gate, not proof of legal ownership.

## Configuration contract

| Section | Current behaviour / integration boundary |
|---|---|
| `Demo:UseSyntheticData` | Default true. Synthetic previews only; false renders a live-setup message. |
| `Access:RequireAllowlist` | Default true; bound for the upcoming admission implementation. No simulated Admin identity or bypass is provided. |
| `Refresh:MinimumSeconds` | Validated 1–3600, default 30. No data refresh polling is active in this shell. |
| `Dashboards:MaxWidgets` | Validated 1–20, default 20. Dashboard preview is read-only; no save API yet. |
| `Telemetry:SamplingRatio` | Validated 0–1, default 0.1. `Telemetry:TraceBasedLogSampling` must remain false. Exporter wiring follows with Azure integration. |
| `AzureAd` | Non-secret sign-in registration settings **only in `Viseg.Connect.Web/appsettings.json`**. Blank TenantId/ClientId are intentional until supplied. Future identity code must bind these settings from that file, without environment/pipeline/IaC overrides. Credentials remain in user-secrets/Key Vault. |
| `ConnectionStrings:AppDatabase` | Reserved for SQL managed-identity integration; no DB connection is opened at startup. |
| `Secrets:VaultUri` | Reserved for server-side secret management; must use the resource-tenant identity. |
| `DataProtection:BlobUri` / `KeyIdentifier` | Reserved for persisted/encrypted keys with Azure integration. Local antiforgery uses standard development Data Protection. |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Reserved for Azure Monitor integration. Explicit managed-identity credential configuration is required when local telemetry authentication is disabled. |

The sign-in tenant and resource tenant may differ. Entra registration details stay in Web `appsettings.json`; Azure resource identity/RBAC configuration stays in Bicep. The CI workflow only validates/packages and has no cloud credentials or deployment step. Coordinate a separate OIDC deployment workflow with the infrastructure owner rather than modifying CI into an implicit deploy job.

## Verify

PowerShell 7 is required for the build scripts. From this directory:

```powershell
dotnet build Viseg.Connect.slnx --no-restore
./build/Verify-Source.ps1
./build/Verify-Dependencies.ps1
./tests/Viseg.Connect.E2E/bin/Debug/net10.0/playwright.ps1 install chromium
dotnet test Viseg.Connect.slnx --no-build
az bicep install --version v0.49.2
./build/Validate-Infrastructure.ps1
```

On Linux CI, browser installation includes `--with-deps`. To use an already-installed Microsoft Edge locally, set `$env:VISEG_BROWSER_CHANNEL='msedge'`. `VISEG_TEST_OUTPUT` optionally selects screenshot output; `dotnet test --results-directory` selects test-result output. Default dependency reports go to the ignored solution `artifacts` directory. Tests start their own loopback server and stop it afterward.

The repository's CONNECT CI workflow runs locked restore, Release build, policy/advisory checks, unit/browser checks, Bicep/parameter compilation and a Linux publish. Source files must be self-contained and must not depend on local ignored planning files. No build requires cloud credentials. Passing local tests does not verify Azure deployment, real Entra sign-in, SQL migrations or live CONNECT behaviour.

## UI conventions

Each feature uses a neutral English `.resx` plus a `sv-SE` resource file through `IStringLocalizer`; API error codes are separate from localized messages. Place new user-facing copy in the feature resources. Data/source identifiers and standardized units are not translated.

Colours have three tiers: `wwwroot/css/tokens/primitives.css`, semantic/component roles in `tokens/themes.css`, and component styles that reference those roles. `fluent-map.css` maps Fluent tokens to the same semantics. Keep black/white canvases and sparse lime/deeper-orange accents; preserve supplied brand artwork. Focus outlines, labels, chart line styles and table alternatives must remain usable in both themes. Exact WCAG conformance requires continued accessibility review as features are added.

Apache ECharts 6.1.0 is served locally. Its source URLs, SHA-256 checksums, LICENSE and NOTICE are preserved under `wwwroot/vendor/echarts`; CI rejects checksum drift. There are no runtime CDN/font dependencies.
