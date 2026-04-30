# 📋 NSG Rule Editor — Specification

> **Version:** 1.0.0-beta
> **Format:** Single HTML file, zero dependencies
> **Target audience:** Azure network administrators

---

## 1. Overview

The NSG Rule Editor is a browser-based tool for creating, editing, analysing, and exporting Azure Network Security Group (NSG) rulesets. It runs entirely client-side as a single HTML file with no external dependencies, frameworks, or build steps.

### Design Constraints

- **Single file** — all HTML, CSS, and JavaScript in one `index.html`
- **Zero dependencies** — no CDN, no npm packages, no frameworks
- **Offline capable** — works by opening the file directly in any modern browser
- **No server** — all processing is client-side; no data leaves the browser

---

## 2. Rule Model

### 2.1 Rule Fields

| Field | Type | Required | Valid Values |
|-------|------|----------|--------------|
| `name` | string | ✅ | Alphanumeric, hyphens, underscores, dots (`/^[a-zA-Z0-9._-]+$/`) |
| `priority` | integer | ✅ | `100` – `4096` |
| `direction` | enum | ✅ | `Inbound`, `Outbound` |
| `access` | enum | ✅ | `Allow`, `Deny` |
| `protocol` | enum | ✅ | `*`, `Tcp`, `Udp`, `Icmp`, `Esp`, `Ah` |
| `sourceAddressPrefix` | string | ✅ | CIDR, service tag, or `*` |
| `sourceAddressPrefixes` | string[] | — | Multiple CIDRs/tags (mutually exclusive with singular) |
| `sourcePortRange` | string | — | Port, range (`80-443`), or `*` |
| `sourcePortRanges` | string[] | — | Multiple ports/ranges (mutually exclusive with singular) |
| `destinationAddressPrefix` | string | ✅ | CIDR, service tag, or `*` |
| `destinationAddressPrefixes` | string[] | — | Multiple CIDRs/tags (mutually exclusive with singular) |
| `destinationPortRange` | string | ✅ | Port, range, or `*` |
| `destinationPortRanges` | string[] | — | Multiple ports/ranges (mutually exclusive with singular) |
| `sourceApplicationSecurityGroups` | object[] | — | ASG references for source (mutually exclusive with source address prefixes) |
| `destinationApplicationSecurityGroups` | object[] | — | ASG references for destination (mutually exclusive with destination address prefixes) |
| `description` | string | — | Free text (warning shown if empty, non-blocking) |

### 2.2 Dual Storage Model

Azure NSG rules use mutually exclusive singular/plural fields for addresses and ports. The app correctly reads and writes both forms:

- **Singular** (`sourceAddressPrefix`) — used when a single value is present
- **Plural** (`sourceAddressPrefixes`) — used when multiple values are present
- **ASG mode** — when an Application Security Group is referenced, ASG fields are used instead of address prefix fields (mutually exclusive)
- On save, the app sets the appropriate field and nulls the other

### 2.3 Azure Constraints

| Constraint | Value |
|-----------|-------|
| Priority range | 100 – 4096 |
| Max rules per NSG | 1000 |
| Priority uniqueness | Must be unique per direction |
| Name uniqueness | Must be unique across the entire NSG |

### 2.4 Validation Rules

On save, `saveRule()` enforces:

1. Name is required
2. Name matches `/^[a-zA-Z0-9._-]+$/`
3. Priority is numeric and within `100`–`4096`
4. Source address is required
5. Destination address is required
6. Destination port is required
7. Priority must be unique per direction
8. Name must be unique
9. Missing description triggers a non-blocking warning

---

## 3. Import

### 3.1 Supported Formats

| Format | Extension | Parser Function |
|--------|-----------|-----------------|
| BICEP | `.bicep` | `parseBicep()` |
| ARM JSON | `.json` | `parseArmJson()` |
| Terraform (HCL) | `.tf` | `parseTerraform()` |
| CSV | `.csv` | `parseCsv()` |

### 3.2 Import Methods

- **Drag and drop** — drop a file onto the drop zone
- **File picker** — click to browse for a file
- **Start from scratch** — begin with an empty ruleset

### 3.3 Parser Behaviour

- All parsers search for NSG resource types and ignore non-NSG resources in the file
- A 500-line IaC file with VNets, VMs, and load balancers will import correctly
- If multiple NSGs are found, a selector dialog is shown
- Warnings are collected and displayed in a warnings panel (never block import)
- `extractBlock()` handles brace-matching with comment awareness (`//`, `/* */`, `#`)
- **ASG references** are fully imported from all IaC formats (BICEP, ARM JSON, Terraform) and round-trip through export

### 3.4 BICEP Parser

- Finds `resource <symbol> 'Microsoft.Network/networkSecurityGroups@<apiVersion>'` blocks
- Extracts `name`, `location`, and `securityRules` array
- Handles parameter references and dynamic names

### 3.5 ARM JSON Parser

- Parses standard ARM template JSON (`$schema`, `resources` array)
- Recursively searches nested resources for NSG type
- Handles ARM expressions (`[parameters(...)]`) in name and location

### 3.6 Terraform Parser

- Finds `resource "azurerm_network_security_group"` blocks
- Imports inline `security_rule {}` blocks only
- Warns about separate `azurerm_network_security_rule` resources (not imported)
- Handles `var.` references (imported as literal strings with warning)
- Maps Terraform field names to internal format (e.g. `source_address_prefix` → `sourceAddressPrefix`)

### 3.7 CSV Parser

- Parses CSV files with standard comma-delimited rows and a header row
- Handles quoted fields correctly (fields containing commas or newlines)
- Uses semicolons for multi-value fields within cells (e.g. `10.0.0.0/8;172.16.0.0/12`)
- CSV files do not include NSG metadata (name, location) — only rule data is imported
- Can be imported via drag-and-drop like other formats

### 3.8 Expression Resolution

During import, the parser detects and resolves parameter/variable references in rule field values.

#### Symbol Table

Each parser scans for declarations:
- **Bicep**: `param <name> <type> = <default>` and `var <name> = <value>`
- **ARM JSON**: `parameters` and `variables` objects with default values
- **Terraform**: `variable` blocks with `default` values and `locals` blocks

The symbol table maps names to resolved literal values.

#### Resolution Process

1. After parsing rules, each field value is checked for expression references
2. Known references (in the symbol table) are resolved automatically
3. String interpolation patterns (e.g., `'${prefix}/24'`) are evaluated
4. Unresolved references trigger the Resolution Modal (see below)

#### Resolution Modal

If any expressions remain unresolved after auto-resolution:
- A modal displays all unresolved parameters/variables
- Users can enter values manually in text fields
- Users can drop a companion file (`.bicepparam`, `parameters.json`, `.tfvars`) into a mini drop zone
- Users can skip — unresolved fields keep the raw expression text with a ⚠️ indicator

#### Expression Metadata

Resolved fields store metadata for export round-tripping:
```
rule.sourceAddressPrefix = '10.0.0.0/16';        // resolved value
rule._expr_sourceAddressPrefix = 'vnetPrefix';    // original expression
```

| Scenario | Export Result |
|----------|-------------|
| Literal value, unchanged | Emit as literal |
| Expression, auto-resolved, unchanged | Re-emit as expression + declaration |
| Expression, auto-resolved, user edited | Emit as literal (expression link broken) |
| Expression, user entered value | Emit as literal |
| Unresolved, user skipped | Re-emit expression reference |

---

## 4. Export

### 4.1 Supported Formats

| Format | Extension | Function | Re-importable |
|--------|-----------|----------|---------------|
| BICEP | `.bicep` | `generateBicep()` | ✅ |
| Terraform | `.tf` | `generateTerraform()` | ✅ |
| ARM JSON | `.json` | `generateArm()` | ✅ |
| Azure CLI | `.sh` | `generateCli()` | ❌ |
| PowerShell | `.ps1` | `generatePowerShell()` | ❌ |
| CSV | `.csv` | `generateCsv()` | ✅ |

### 4.2 Export Behaviour

- Azure's 6 default rules are **excluded** from all exports (Azure creates them automatically)
- All exports include a `Generated by NSG Rule Editor (DJ Tools)` identifier
- Correctly emits singular vs plural address/port fields based on value count
- Handles dynamic names and parameterised locations
- **ASG references** are correctly emitted in all 6 export formats
- ASG names are shown with an "ASG:" prefix in the rule table

### 4.3 Flush Connection Toggle

- Checkbox in the export modal: **"Flush existing connections on update"**
- When enabled, emits `flushConnection: true` in BICEP, `"flushConnection": true` in ARM JSON, and `-FlushConnection` in PowerShell
- CLI export includes a comment noting the flush connection limitation
- Forces existing connections to re-evaluate against updated rules

### 4.4 Diff View

- Compares original imported rules against current state
- Shows added, removed, and unchanged rule counts
- Available as the 6th tab in the export modal (no download)

### 4.5 Export Actions

- **Copy to clipboard** — copies the generated code
- **Download** — saves as a file with the appropriate extension

### 4.6 Companion Parameter Files

IaC exports automatically generate companion files alongside the main template:

| Format | Companion File | Content |
|--------|---------------|---------|
| Bicep | `.bicepparam` | `using` reference + parameter assignments |
| ARM JSON | `parameters.json` | Parameter values JSON |
| Terraform | `.tfvars` | Variable assignments in HCL |

Companion files are only generated when the exported template contains parameterised values (from expression round-tripping).

### 4.7 Inline Values Toggle

The export modal includes an **"Inline all values"** checkbox:
- When checked, all expressions are replaced with their resolved literal values in the export
- Parameter/variable declarations are omitted from the exported template
- Companion parameter files are not generated
- Useful when the user wants a simple, self-contained template without external parameters

### 4.8 Format Conversion

The editor supports importing from any supported format and exporting to any other format:

- **Internal Rule Model**: All imported rules are normalised to a common internal format
- **Format-agnostic editing**: Users edit rules without awareness of the original format
- **Any-to-any export**: 4 import formats × 6 export formats = 24 possible conversions

Example workflows:
- Import Bicep → Export Terraform (migrate IaC tool)
- Import ARM JSON → Export Bicep (modernise templates)
- Import Terraform → Export Azure CLI (generate one-off scripts)
- Import CSV → Export ARM JSON (spreadsheet to IaC)

---

## 5. Templates

### 5.1 Template Library

20 pre-built rule templates:

| Template | Direction | Access | Port | Protocol |
|----------|-----------|--------|------|----------|
| Allow-HTTPS-Inbound | Inbound | Allow | 443 | Tcp |
| Allow-HTTP-Inbound | Inbound | Allow | 80 | Tcp |
| Allow-SSH-Inbound | Inbound | Allow | 22 | Tcp |
| Allow-RDP-Inbound | Inbound | Allow | 3389 | Tcp |
| Allow-AzureLB-Inbound | Inbound | Allow | * | * |
| Allow-VNet-Inbound | Inbound | Allow | * | * |
| Allow-VNet-Outbound | Outbound | Allow | * | * |
| Allow-Internet-Outbound | Outbound | Allow | * | * |
| Deny-All-Inbound | Inbound | Deny | * | * |
| Deny-All-Outbound | Outbound | Deny | * | * |
| Deny-Internet-Inbound | Inbound | Deny | * | * |
| Allow-DNS-Outbound | Outbound | Allow | 53 | * |
| Allow-SQL-Inbound | Inbound | Allow | 1433 | Tcp |
| Allow-MySQL-Inbound | Inbound | Allow | 3306 | Tcp |
| Allow-PostgreSQL-Inbound | Inbound | Allow | 5432 | Tcp |
| Allow-SMTP-Outbound | Outbound | Allow | 587 | Tcp |
| Allow-NTP-Outbound | Outbound | Allow | 123 | Udp |
| Allow-AzureMonitor-Outbound | Outbound | Allow | 443 | Tcp |
| Allow-KeyVault-Outbound | Outbound | Allow | 443 | Tcp |
| Allow-Storage-Outbound | Outbound | Allow | 443 | Tcp |

### 5.2 Template Behaviour

- Auto-assigns priority: `max(existing priorities) + 100`, capped at `4096`
- Duplicate name protection — prevents adding a template that already exists
- One-click add from the template panel

---

## 6. Analysis Engine

### 6.1 Checks Performed

| Check | Description | Rendering |
|-------|-------------|-----------|
| **Conflicts** | Rules with overlapping match criteria but opposite `access` values in the same direction | ⚠️ warning panel |
| **Shadows** | Earlier (lower priority) rule completely covers a later rule, making it unreachable | ⚠️ warning panel |
| **Priority gaps** | Adjacent custom rules with gap < 10 (no room to insert between) | 📐 warning with auto-renumber button |
| **Default rules** | Shows Azure's 6 built-in default rules as a read-only reference | 🛡️ reference table |
| **Deprecated tags** | Rules using deprecated service tags (`AzureUpdateDelivery`, `AzureFrontDoor.FirstParty`, `AzureContentDelivery`) | ⚠️ warning with strikethrough |
| **Hit count docs** | Info box linking to NSG Flow Logs and Traffic Analytics in Azure Monitor | ℹ️ documentation links |
| **Duplicates** | Rules with identical traffic criteria (direction + protocol + source + dest + ports) at different priorities | 🔁 warning panel |

### 6.2 Conflict Detection

- Compares all rule pairs in the same direction
- Flags when two rules have overlapping protocol, address, and port criteria but opposite `access` values
- Overlap is determined by set intersection (not simple equality)

### 6.3 Shadow Detection

- A rule is shadowed when an earlier (lower priority number) rule matches all traffic the later rule would match
- Coverage is determined by checking if the earlier rule's criteria is a superset

### 6.4 Priority Gap Detection

- Flags adjacent custom rule priorities with a gap smaller than 10
- Offers an **auto-renumber** button that reassigns priorities in steps of 100

### 6.5 Analysis Badge

- Shows total issue count (conflicts + gaps + defaults) in the section header
- Displays `✓ No issues` when all checks pass

---

## 7. Security & Compliance

### 7.1 Security Score

Score starts at **100** with weighted deductions:

| Check | Deduction | Condition |
|-------|-----------|-----------|
| RDP exposed to Internet | −25 | Inbound Allow on port 3389 with source `*` or `Internet` |
| SSH exposed to Internet | −25 | Inbound Allow on port 22 with source `*` or `Internet` |
| Any-to-any inbound allow | −20 | Inbound Allow with all wildcards |
| Broad port range | −10 | Inbound Allow with `*`, `0-65535`, or range spanning >1000 ports |
| SMB (445) exposed | −15 | Inbound Allow on port 445 with broad source |
| Missing descriptions | −10 | Fewer than 50% of rules have descriptions |
| Missing descriptions (partial) | −5 | 50%–99% of rules have descriptions |
| No explicit deny strategy | −5 | No custom deny rules present |

### 7.2 Grade Scale

| Grade | Score Range |
|-------|------------|
| A | ≥ 90 |
| B | ≥ 80 |
| C | ≥ 70 |
| D | ≥ 60 |
| F | < 60 |

### 7.3 Compliance Mappings

Each check maps to relevant controls in:

- **Azure Security Benchmark v3**
- **CIS Azure Foundations**
- **NIST 800-53 AC-4**

---

## 8. What-If Traffic Simulator

### 8.1 Inputs

| Field | Description |
|-------|-------------|
| Direction | `Inbound` or `Outbound` |
| Source Address | IP address or CIDR |
| Source Port | Port number or `*` |
| Destination Address | IP address or CIDR |
| Destination Port | Port number or `*` |
| Protocol | `Tcp`, `Udp`, `Icmp`, `*`, etc. |

### 8.2 Behaviour

- Combines custom rules with Azure's 6 default rules
- Sorts all rules by priority (ascending)
- Evaluates using Azure's **first-match** logic — the first matching rule determines the outcome
- Displays the matching rule and full evaluation trace showing each rule checked

---

## 9. CIDR Calculator

### 9.1 Outputs

| Field | Description |
|-------|-------------|
| Network address | First address in the subnet |
| Broadcast address | Last address in the subnet |
| Subnet mask | Dotted decimal mask |
| Wildcard mask | Inverse of subnet mask |
| First usable host | Network + 1 |
| Last usable host | Broadcast − 1 |
| Total addresses | 2^(32 − prefix) |
| Usable hosts | Total − 2 |
| Azure usable IPs | Total − 5 (Azure reserves 5 addresses per subnet) |
| CIDR notation | Standard slash notation |
| IP range | First – last address |

### 9.2 Azure Considerations

- Azure reserves **5** IP addresses per subnet (network, gateway, DNS×2, broadcast)
- Subnets smaller than `/29` are flagged as too small for Azure

---

## 10. Reference Panels

### 10.1 Common Ports

**38** well-known port entries with name, port number, protocol, and description. Clicking a port card creates a new rule pre-populated with that port as source or destination.

### 10.2 Azure Service Tags

**34** Azure service tags (e.g. `VirtualNetwork`, `AzureLoadBalancer`, `Internet`, `Storage`, `Sql`). Clicking a service tag creates a new rule pre-populated with that tag.

**Deprecated tags:** 3 tags are flagged as deprecated: `AzureUpdateDelivery`, `AzureFrontDoor.FirstParty`, and `AzureContentDelivery`. These are shown with strikethrough styling in the service tag reference panel. Saving a rule that uses a deprecated tag triggers a non-blocking warning toast.

---

## 11. Azure Default Rules

### 11.1 Built-in Rules

Azure automatically applies 6 default rules to every NSG (priority 65000–65500):

| Rule | Priority | Direction | Access | Source | Destination |
|------|----------|-----------|--------|--------|-------------|
| AllowVNetInBound | 65000 | Inbound | Allow | VirtualNetwork | VirtualNetwork |
| AllowAzureLoadBalancerInBound | 65001 | Inbound | Allow | AzureLoadBalancer | 0.0.0.0/0 |
| DenyAllInBound | 65500 | Inbound | Deny | 0.0.0.0/0 | 0.0.0.0/0 |
| AllowVnetOutBound | 65000 | Outbound | Allow | VirtualNetwork | VirtualNetwork |
| AllowInternetOutBound | 65001 | Outbound | Allow | 0.0.0.0/0 | Internet |
| DenyAllOutBound | 65500 | Outbound | Deny | 0.0.0.0/0 | 0.0.0.0/0 |

### 11.2 Behaviour

- Shown as a **read-only reference** in the Default Rules section
- **Not editable** — users cannot add or remove them
- **Excluded from exports** — Azure creates them automatically
- Used in the What-If simulator for accurate first-match evaluation

---

## 12. Rule Capacity Gauge

| Parameter | Value |
|-----------|-------|
| Maximum rules | 1000 |
| Bar segments | 20 |
| Green zone | < 50% |
| Amber zone | 50% – 79% |
| Red zone | ≥ 80% |
| Warning threshold | 80% (displays capacity warning) |

---

## 13. Bulk Operations

### 13.1 Selection

- **Select all** — selects all visible rules
- **Select by direction** — select all inbound or all outbound
- **Clear selection** — deselects all

### 13.2 Actions

| Action | Description |
|--------|-------------|
| Toggle Allow/Deny | Flips `access` on all selected rules |
| Toggle Direction | Flips `direction` on all selected rules |
| Delete Selected | Removes all selected rules (with confirmation) |

---

## 14. Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Z` | Undo |
| `Ctrl+Y` | Redo |
| `Ctrl+K` | Open command palette |
| `N` | New rule |
| `E` | Export |
| `T` | Templates |
| `?` | Show keyboard shortcuts |
| `Del` | Delete selected rule |
| `Esc` | Close modal |

---

## 15. Command Palette

Opened with `Ctrl+K`, provides quick access to:

| Command | Action |
|---------|--------|
| New Rule | Opens the add rule form |
| Export NSG | Opens the export modal |
| Reset / New NSG | Clears all rules and starts fresh |
| Toggle Theme | Switches between light and dark mode |
| Undo | Reverts the last change |
| Redo | Re-applies the last undone change |
| Show Keyboard Shortcuts | Opens the shortcuts reference |
| Show Guided Tips | Displays onboarding tips |
| Expand Security Rules | Expands the security rules section |
| Expand All Sections | Opens all collapsible sections |
| Collapse All Sections | Closes all collapsible sections |

---

## 16. Undo / Redo

- Full undo/redo history stack
- `pushUndo()` is called before every mutation (add, edit, delete, bulk, renumber)
- `Ctrl+Z` and `Ctrl+Y` keyboard shortcuts
- Toolbar buttons with disabled state when stack is empty

---

## 17. Audit Log

### 17.1 Tracked Actions

`Add`, `Edit`, `Delete`, `Duplicate`, `Import`, `Add Template`, `Renumber`, `Bulk Delete`, `Bulk Toggle Access`, `Bulk Toggle Direction`, `Create`

### 17.2 Metadata Stored

| Field | Description |
|-------|-------------|
| Timestamp | When the action occurred |
| Action | Action type with icon |
| Details | Human-readable summary |
| Rule metadata | Name, priority, direction, access, protocol, addresses, ports |
| Before state | Previous values for edit operations (field-level diff) |

### 17.3 CSV Export

- Per-rule CSV with one row per rule for multi-rule operations
- Includes all rule fields and change details

---

## 18. Theme System

### 18.1 Modes

- **Light** — default
- **Dark** — toggled via header button or `Ctrl+D`
- **System preference** — auto-detects `prefers-color-scheme`

### 18.2 CSS Variables

All colours and styling are controlled via CSS custom properties on `:root`:

| Category | Variables |
|----------|-----------|
| Brand | `--brand-primary`, `--brand-hover`, `--brand-pressed`, `--brand-subtle`, `--brand-bg` |
| Background | `--bg-base`, `--bg-layer1`, `--bg-layer2`, `--bg-hover` |
| Borders | `--border-default`, `--border-subtle` |
| Text | `--text-primary`, `--text-secondary`, `--text-tertiary`, `--text-on-brand` |
| Status | `--status-danger`, `--status-danger-bg`, `--status-success`, `--status-success-bg`, `--status-warning`, `--status-warning-bg`, `--status-info-bg` |
| Layout | `--radius-sm`, `--radius-md`, `--radius-lg`, `--shadow-sm`, `--shadow-md`, `--shadow-lg` |
| Typography | `--font-sans` |
| Motion | `--transition` |

### 18.3 Design Language

- **Fluent UI / Microsoft 365** visual style
- Segoe UI font stack
- Rounded corners, subtle shadows, consistent spacing

---

## 19. Visual Components

### 19.1 Firewall Shield Diagram

- Flow diagram showing rule distribution across inbound and outbound directions
- Visual representation of allow vs deny rule balance

### 19.2 Resizable Table Columns

- Rule tables support column resizing via drag handles

### 19.3 Smart Search

- Filters rules across all fields: name, description, priority, protocol, ports, addresses
- Live match count displayed as `X / Y` when filter is active

---

## 20. Deployment

### 20.1 Hosted Version

- Deployed to **Azure Static Web Apps** (Free tier)
- URL: `https://nsgeditor.djtools.co.nz/`

### 20.2 Local Usage

- Download `index.html` and open in any modern browser
- No install, no server, no configuration required

---

## 21. Project Structure

```
djtools-nsg-editor/
├── index.html          # The app (single file, zero dependencies)
├── README.md           # Project overview and usage guide
├── LICENSE             # MIT license
├── docs/
│   ├── SPEC.md         # This specification
│   ├── howitworks.md   # Technical deep-dive documentation
│   └── talktrack.md    # DevOps demo talk track
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   └── feature_request.yml
│   └── pull_request_template.md
└── .gitignore
```

---

## 22. Auto-Save

### 22.1 Behaviour

- Editor state is automatically saved to `localStorage` on every rule change
- Key: `nsgEditor_state`
- Serialises: `nsgState`, `originalRules`, `auditLog`, and `savedAt` timestamp

### 22.2 Restore

On page load, if saved state exists, a banner appears on the drop zone:
- **"Resume Session"** — loads the saved state
- **"Start Fresh"** — clears localStorage and shows the empty drop zone

### 22.3 Lifecycle

| Event | Action |
|-------|--------|
| Any rule change | Auto-save triggered (via `updateDisplay()`) |
| Page load with saved state | Restore banner shown |
| User clicks "Resume Session" | Saved state loaded |
| User clicks "Start Fresh" | localStorage cleared |
| User clicks "Reset / New NSG" | localStorage cleared |
| File dropped for import | Saved state overwritten on next update |

---

## 23. Duplicate Rule Detection

### 23.1 Fingerprint

Each rule generates a fingerprint: `${direction}|${protocol}|${sourceAddress}|${destAddress}|${sourcePort}|${destPort}`

### 23.2 Detection

- Only custom rules are checked (Azure default rules excluded)
- Duplicate pairs are displayed in the analysis panel
- Pairs with different `access` decisions (Allow vs Deny) are flagged with an additional warning

### 23.3 Rendering

- Displayed as "🔁 Duplicate Rules Detected (N)" in the analysis section
- Each pair shows both rule names and the matching criteria
- Duplicate count is included in the analysis badge total
