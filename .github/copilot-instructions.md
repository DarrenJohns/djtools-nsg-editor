# Copilot Instructions — NSG Rule Editor

## Project Overview
This is a **single-file HTML web application** (`index.html`) for configuring Azure Network Security Group (NSG) rulesets. It runs as a static site on Azure Static Web Apps with no server-side components, build tools, or dependencies. All processing is client-side — no data leaves the browser.

## Architecture
- **Single file**: All HTML, CSS, and JavaScript live in `index.html` (~4300+ lines: ~600 lines CSS, ~3800 lines JS)
- **No frameworks**: Pure vanilla HTML/CSS/JS — no React, Vue, npm, etc.
- **No build step**: The file deploys directly as a static site
- **Static hosting**: Azure Static Web Apps (URL: `https://nsgeditor.djtools.co.nz/`)

## Code Map (where things live in `index.html`)
- **Parsers** — functions named `parse<Format>(content)`: `parseBicep`, `parseArmJson`, `parseTerraform`, `parseCsv`. Companion-file parsers: `parseParametersJson`, `parseBicepparam`, `parseTfvars`. All NSG parsers scan for `Microsoft.Network/networkSecurityGroups` resources and ignore unrelated content.
- **Generators** — functions named `generate<Format>()`: `generateBicep`, `generateTerraform`, `generateArm`, `generateCli`, `generatePowerShell`, `generateCsv`. Companion-file generators: `generateBicepparam`, `generateTfvars`, `generateArmParams`.
- **Universal rule model**: parsers convert any input format into a single internal rule object; generators emit from that same object. Format conversion (e.g. Bicep → Terraform) is a side effect of import + export.

## Key Internal Conventions
- **`_expr` metadata**: Imported parameters/variables/locals/interpolations are resolved to a literal value, but the original expression is preserved on the rule under `rule._expr.<fieldName> = { symbol, declKind, resolved, original, status? }`. Generators consult `_expr` to round-trip the original expression back out on export. **When adding a new field that may come from a parameter, also wire it through `_expr`.**
- **Unresolved expressions**: parsers mark them with `status: 'unresolved'` on `_expr`, which triggers the resolution modal in the UI. Don't silently drop or hard-fail on unresolved values.
- **Singular vs plural fields**: Azure NSG rules use mutually-exclusive singular/plural pairs (`sourceAddressPrefix` ↔ `sourceAddressPrefixes`, same for destination and ports). On save, set the appropriate field and **null the other**. Same rule applies to ASG mode: when `sourceApplicationSecurityGroups` is set, address-prefix fields must be null (and vice versa).
- **Default rules**: Azure auto-creates 6 default rules (priority 65000–65500). The app shows them as read-only reference and **never includes them in exports**.
- **Export watermarks**: every export format embeds a generator comment/metadata identifying the app + version.

## Git & Deployment Workflow
- **GitHub Flow**: Always create a feature branch → PR → merge to `main`
- **Branch naming**: Use prefixes like `feature/`, `fix/`, `docs/`, `chore/`
- **CI/CD**: Push to `main` triggers `.github/workflows/deploy.yml` (GitHub-hosted `ubuntu-latest` runner) which deploys `index.html` to Azure Static Web Apps via `@azure/static-web-apps-cli`. The deployment token lives in the `production` GitHub Environment (branch-restricted to `main`).
- **Validation**: `.github/workflows/validate.yml` runs HTML structural checks on PRs touching `*.html`. It uses `pull_request` (not `pull_request_target`), so PRs from forks run with **no secret access**.
- **Pinning**: third-party actions are pinned to commit SHA — update the `# vX.Y.Z` comment beside each `@<sha>` when bumping.

## Version Numbering
- Format: `vX.Y.Z-beta` (currently v1.0.0-beta)
- Update version in **three places**: footer in index.html, ARM generator metadata in index.html, README badge
- Bump version for feature changes, not doc-only changes

## Code Conventions
- Keep everything in the single `index.html` file
- Minimal code comments — only where clarification is needed
- CSS uses custom properties (variables) for theming (light/dark mode)
- JavaScript uses modern ES6+ (const/let, arrow functions, template literals, async/await)
- No external CDN dependencies

## Documentation
- `README.md` — Project overview (stays in repo root)
- `docs/SPEC.md` — Full application specification
- `docs/howitworks.md` — Technical deep-dive
- `docs/talktrack.md` — DevOps demo talk track

## Key Technical Details
- **Import formats**: BICEP, ARM JSON, Terraform, CSV (auto-detected from file extension in `handleFile`)
- **Export formats**: BICEP, ARM JSON, Terraform, Azure CLI, PowerShell, CSV (= 4 × 6 = 24 conversion combinations)
- **Companion files**: Bicep/ARM/Terraform exports also emit `.bicepparam` / `parameters.json` / `.tfvars`. Companion files can also be **imported** to resolve unresolved parameters in a previously imported template.
- **HTML validation quirk**: tags inside JS template strings cause false positives in tag counting — be aware if you ever add CI-side HTML structural validation.

## Testing
- No automated unit tests — validation is manual + HTML structure validation in CI
- Always test import/export round-trips when changing parser or generator code
- Hard refresh (`Ctrl+Shift+R`) after deployments to bypass browser cache

## Documentation Updates
Any feature added, changed, or removed requires updating these docs before merging:
- `README.md` — Features list, import/export formats, how-to sections
- `docs/SPEC.md` — Full specification (rule model, import, export, analysis)
- `docs/howitworks.md` — Technical deep-dive (parsers, generators, analysis)
- `docs/talktrack.md` — Demo talk track (version, recent features, talking points)
