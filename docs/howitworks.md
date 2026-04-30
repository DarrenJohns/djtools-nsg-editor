# 🔬 How It Works — NSG Rule Editor Under the Hood

> **A deep dive into how every feature is built — zero dependencies, one HTML file, pure JavaScript**

---

## 📐 Architecture Overview

The entire app lives in a single `index.html` file with three embedded sections:

| Section | Purpose |
|---------|---------|
| `<style>` | ~600 lines of CSS using custom properties for theming |
| `<body>` | Semantic HTML with collapsible accordion sections |
| `<script>` | ~3800 lines of vanilla JavaScript — no frameworks, no libraries |

**Why single-file?** It can be dropped into any static host (Azure Static Web Apps, S3, GitHub Pages) with zero build steps. Open it locally and it just works.

---

## 🎨 Theme System — Dark & Light Modes

**How it works:** CSS custom properties + a `data-theme` attribute on `<html>`.

```css
/* Default (light) theme */
:root {
  --bg-primary: #f5f5f5;
  --text-primary: #1a1a1a;
  --brand-primary: #0078d4;
}

/* Dark theme overrides */
[data-theme="dark"] {
  --bg-primary: #1e1e1e;
  --text-primary: #e0e0e0;
  --brand-primary: #4fc3f7;
}
```

**Key functions:**
- `toggleTheme()` — flips the attribute and saves to `localStorage`
- `initTheme()` — on page load, checks saved preference or falls back to `prefers-color-scheme`

**💡 Technique:** Every colour in the app uses `var(--property-name)`, so changing one attribute on the root element instantly re-themes the entire UI — no JavaScript DOM manipulation needed.

---

## 📂 File Import — Drag & Drop Parser

### 🖱️ The Drop Zone

The drop zone listens for `dragover`, `dragleave`, and `drop` events. When a file lands:

```js
function handleFile(file) {
  const ext = file.name.split('.').pop().toLowerCase();
  const reader = new FileReader();
  reader.onload = (e) => {
    if (ext === 'json') parseArmJson(e.target.result);
    else if (ext === 'tf') parseTerraform(e.target.result);
    else if (ext === 'csv') parseCsv(e.target.result);
    else parseBicep(e.target.result);
  };
  reader.readAsText(file);
}
```

**Supported formats:** `.bicep`, `.json` (ARM templates), `.tf` (Terraform HCL), and `.csv`. The IaC parsers use the same strategy — scan the file for NSG-specific resource types and ignore everything else, so files with dozens of other resources work fine. The CSV parser handles quoted fields and uses semicolons for multi-value fields within cells.

### 📄 BICEP Parser

BICEP files aren't JSON — they're a DSL (Domain-Specific Language). The parser works in stages:

**Stage 1 — Find the NSG resource:**
```js
const regex = /resource\s+(\w+)\s+'Microsoft\.Network\/networkSecurityGroups@([^']+)'\s*=\s*\{/g;
```

**Stage 2 — Extract the block with brace matching:**

This is the clever part. You can't use regex to match nested braces, so `extractBlock()` walks character-by-character tracking brace depth and string literals:

```js
function extractBlock(text, startIndex) {
  let depth = 0, inString = false;
  for (let i = startIndex; i < text.length; i++) {
    if (text[i] === "'" && !inString) inString = true;
    else if (text[i] === "'" && inString) inString = false;
    else if (!inString) {
      if (text[i] === '{') depth++;
      if (text[i] === '}') { depth--; if (depth === 0) return text.slice(startIndex, i + 1); }
    }
  }
}
```

**Stage 3 — Parse each rule** using helper functions like `getStr()`, `getNum()`, `getArr()` that extract typed values from the BICEP block text.

**💡 Technique:** A manual recursive-descent parser instead of fragile regex-only parsing. This handles nested objects, quoted strings, and comments correctly.

### 📋 ARM JSON Parser

ARM templates are valid JSON, so parsing is simpler — but NSG resources can be nested:

```js
function findNsgResources(resources) {
  for (const res of resources) {
    if (res.type.toLowerCase() === 'microsoft.network/networksecuritygroups') {
      // Extract rules from res.properties.securityRules
    }
    if (res.resources) findNsgResources(res.resources); // Recurse!
  }
}
```

**💡 Technique:** Recursive traversal handles both top-level and nested resource definitions in ARM templates.

### 🟦 Terraform (HCL) Parser

Terraform files use HCL syntax. The parser finds `azurerm_network_security_group` resources and extracts inline `security_rule` blocks:

```js
const resourceRegex = /resource\s+"azurerm_network_security_group"\s+"(\w+)"\s*\{/g;
// For each match, extract the block and parse security_rule sub-blocks
```

**Key design decisions:**
- Reuses the same `extractBlock()` brace-matcher as the BICEP parser (extended to handle `#` comments used in HCL)
- Handles both quoted values (`name = "value"`) and variable references (`location = var.location`)
- Warns when separate `azurerm_network_security_rule` resources are detected (only inline rules are imported)
- Maps Terraform field names to internal format (e.g. `source_address_prefix` → `sourceAddressPrefix`)

**💡 Technique:** All three parsers (BICEP, ARM, Terraform) search specifically for NSG resource types and ignore everything else in the file — so a 500-line IaC file with VNets, VMs, and load balancers will still import correctly.

### 🏷️ DJ Tools Watermark

Every exported file includes a `Generated by NSG Rule Editor (DJ Tools)` identifier:
- **BICEP/Terraform:** Comment at the top of the file
- **ARM JSON:** `_generator` metadata field in the template
- **CLI/PowerShell:** Comment header

---

## ✏️ Rule Editor — Validation & Dual Storage Model

### Validation Rules

When saving a rule, `saveRule()` enforces Azure's actual constraints:

| Field | Validation |
|-------|-----------|
| Name | Required, alphanumeric + hyphens/underscores only |
| Priority | Integer between 100–4096 |
| Source/Dest Address | Required (IP, CIDR, service tag, or `*`) |
| Duplicate check | No two rules can share the same name or priority |

### The Dual Storage Model

Azure NSG rules have a quirk: single values use `sourceAddressPrefix` (singular), but multiple values use `sourceAddressPrefixes` (plural array). The editor handles both:

```js
const addresses = splitField(sourceAddress);
if (addresses.length > 1) {
  rule.sourceAddressPrefixes = addresses;
} else {
  rule.sourceAddressPrefix = addresses[0];
}
```

**ASG mode toggle:** The rule editor includes a mode toggle (Address vs ASG) for source and destination fields. When ASG mode is selected, the rule references Application Security Groups instead of address prefixes. ASG fields (`sourceApplicationSecurityGroups`, `destinationApplicationSecurityGroups`) are mutually exclusive with address prefix fields. ASG names are displayed with an "ASG:" prefix in the rule table. Full round-trip is supported: import ASG references from BICEP, ARM JSON, or Terraform, edit them, and export to all 6 formats.

This ensures exported BICEP/ARM/CLI matches exactly what Azure expects.

---

## 🧮 CIDR Calculator — Binary Subnet Math

This is one of the most educational sections. It converts human-readable CIDR notation (e.g., `10.0.1.0/24`) into network details using **bitwise arithmetic**.

### Step 1 — IP Address to 32-bit Integer

An IPv4 address is four octets. To do math on it, convert to a single 32-bit number:

```js
function ipToInt(ip) {
  const parts = ip.split('.').map(Number);
  return (parts[0] << 24 | parts[1] << 16 | parts[2] << 8 | parts[3]) >>> 0;
}
// Example: 10.0.1.0 → 167772416
```

The `>>> 0` forces an **unsigned** right shift, preventing JavaScript from treating the result as a negative signed integer.

### Step 2 — Build the Subnet Mask

A `/24` prefix means the first 24 bits are the network, leaving 8 bits for hosts:

```js
const mask = (~0 << (32 - bits)) >>> 0;
// /24 → 11111111.11111111.11111111.00000000 → 255.255.255.0
```

`~0` is all 1s (32 bits). Shifting left by `(32 - bits)` zeros out the host portion.

### Step 3 — Calculate Network & Broadcast

```js
const network   = ipInt & mask;          // AND: zero out host bits
const broadcast = network | (~mask >>> 0); // OR: set all host bits to 1
```

### Step 4 — Count Usable Hosts

```js
const totalHosts = broadcast - network + 1;
const usableHosts = totalHosts - 2;       // Subtract network + broadcast
const azureUsable = totalHosts - 5;       // Azure reserves 5 addresses
```

**🔵 Azure-specific:** Azure reserves 5 IPs per subnet (network, broadcast, gateway, and 2 DNS), so a `/29` (8 addresses) only gives you **3 usable hosts**.

### Step 5 — CIDR Containment Check

To determine if one CIDR range contains another (used in conflict detection):

```js
function cidrContains(outer, inner) {
  const [oNet, oBits] = parseCidr(outer);
  const [iNet, iBits] = parseCidr(inner);
  if (oBits > iBits) return false;  // Outer is smaller, can't contain
  const mask = (~0 << (32 - oBits)) >>> 0;
  return (oNet & mask) === (iNet & mask);
}
```

**💡 Technique:** All calculations use unsigned 32-bit bitwise operations — the same math that real network hardware uses to route packets.

---

## 🔍 Analysis Engine — Conflicts, Shadows & Gaps

The analysis engine runs multiple checks across all rules and caches results for performance.

### ⚔️ Conflict Detection

Two rules **conflict** when they match the same traffic but have opposite actions (one Allow, one Deny):

```js
function detectConflicts() {
  for (let i = 0; i < rules.length; i++) {
    for (let j = i + 1; j < rules.length; j++) {
      if (rules[i].access === rules[j].access) continue;      // Same action = no conflict
      if (rules[i].direction !== rules[j].direction) continue; // Different direction = no conflict
      if (!protocolsOverlap(r1, r2)) continue;
      if (!addrsOverlap(r1, r2)) continue;
      if (!portsOverlap(r1, r2)) continue;
      // If we get here, it's a conflict!
    }
  }
}
```

### 👻 Shadow Detection

A rule is **shadowed** when an earlier (lower priority) rule already matches all the same traffic — meaning the later rule will never be evaluated:

```js
function ruleCovers(ruleA, ruleB) {
  // ruleA "covers" ruleB if every possible match of B is also matched by A
  return fieldSetCovers(ruleA.sources, ruleB.sources, addressCovers)
      && fieldSetCovers(ruleA.sourcePorts, ruleB.sourcePorts, portCovers)
      && fieldSetCovers(ruleA.dests, ruleB.dests, addressCovers)
      && fieldSetCovers(ruleA.destPorts, ruleB.destPorts, portCovers);
}
```

The `fieldSetCovers()` function checks that **every value** in rule B's field set is covered by **at least one value** in rule A's field set.

### 📏 Priority Gap Detection

Flags when consecutive custom rules have priorities too close together (gap < 10), leaving no room to insert rules between them:

```js
const sorted = rules.map(r => r.priority).sort((a, b) => a - b);
for (let i = 1; i < sorted.length; i++) {
  if (sorted[i] - sorted[i-1] < 10) gaps.push(/* ... */);
}
```

### 🔒 Caching

Analysis is expensive on large rulesets, so results are cached and invalidated by a revision counter:

```js
let rulesRevision = 0;  // Incremented on every rule change
function getCachedAnalysis() {
  if (cachedRevision === rulesRevision) return cachedResult;
  // Recalculate...
}
```

**💡 Technique:** Lazy cache invalidation — analysis only re-runs when rules actually change.

### ⚠️ Deprecated Service Tag Warnings

The analysis engine flags rules that reference deprecated Azure service tags:

- **`AzureUpdateDelivery`**, **`AzureFrontDoor.FirstParty`**, and **`AzureContentDelivery`** are marked as deprecated
- Rules using these tags trigger a non-blocking warning toast when saved
- Deprecated tags are shown with strikethrough styling in the service tag reference panel
- The analysis section lists all rules using deprecated tags for easy identification

### 📊 Rule Hit Count Documentation

An info box at the bottom of the analysis section links to **NSG Flow Logs** and **Traffic Analytics** in Azure Monitor. This helps administrators understand which rules are actively matching traffic — no manual hit count field is provided, just direct links to Azure's monitoring tools.

### 🔎 Smart Rule Search

The search box filters rules across **all fields** — not just name and description:

```js
const fields = [r.name, r.description||'', r.protocol||'', String(r.priority||''),
  r.sourceAddressPrefix||'', (r.sourceAddressPrefixes||[]).join(' '),
  r.sourcePortRange||'', (r.sourcePortRanges||[]).join(' '),
  r.destinationAddressPrefix||'', (r.destinationAddressPrefixes||[]).join(' '),
  r.destinationPortRange||'', (r.destinationPortRanges||[]).join(' ')];
if (!fields.some(f => f.toLowerCase().includes(searchTerm))) return false;
```

When filters are active, the rule count header shows `X / Y` (matching rules / total rules) so you always know how many results are hidden.

**💡 Technique:** Case-insensitive substring matching across a flattened array of all rule properties — works with both singular and plural Azure fields.

---

## 🛡️ Security Score — Weighted Heuristic Scoring

The security score starts at 100 and subtracts penalties for risky configurations:

| Check | Penalty | Why |
|-------|---------|-----|
| RDP (3389) open to Internet | -25 | Top attack vector |
| SSH (22) open to Internet | -20 | Brute force target |
| Any-to-any inbound Allow | -30 | No protection at all |
| Broad port ranges (>1000 ports) | -10 | Excessive exposure |
| Missing rule descriptions | -5 | Audit/compliance gap |
| SMB (445) exposed | -10 | Ransomware vector |
| No explicit deny-all | -10 | Defence-in-depth gap |

Results are mapped to compliance frameworks:

```
Score 80+ → ✅ ASB (Azure Security Benchmark)
Score 70+ → ✅ CIS Benchmark
Score 60+ → ✅ NIST 800-53
```

The score is rendered as an **SVG circular gauge** using stroke dash offset:

```js
const circumference = 2 * Math.PI * radius;
const dashOffset = circumference - (score / 100) * circumference;
```

---

## 🔮 What-If Simulator — NSG Evaluation Engine

Tests "would this traffic be allowed or denied?" by simulating Azure's actual NSG evaluation logic:

```js
function runWhatIf() {
  const flow = { protocol, sourceAddr, sourcePort, destAddr, destPort, direction };
  const sorted = [...customRules, ...azureDefaults].sort((a, b) => a.priority - b.priority);

  for (const rule of sorted) {
    const matches = ruleMatchesFlow(rule, flow);
    if (matches && !matchedRule) matchedRule = rule; // First match wins!
  }
}
```

**🔑 Key insight:** Azure NSGs use **first-match evaluation** — rules are checked in priority order (lowest number first), and the first matching rule determines the outcome. This is exactly how the simulator works.

The output shows a trace of every rule checked, highlighting which one matched.

---

## 📤 Export System — 6 Formats from One Model

All exports read from the same canonical rule array but generate format-specific output:

### 📘 BICEP Export
```js
function generateBicep() {
  return rules.map(r => `
    {
      name: '${r.name}'
      properties: {
        priority: ${r.priority}
        direction: '${r.direction}'
        access: '${r.access}'
        protocol: '${r.protocol}'
        // ...
      }
    }`).join('\n');
}
```

### 🟦 Terraform Export
Generates `azurerm_network_security_rule` resources with proper HCL syntax.

### 📋 ARM JSON Export
Outputs a complete ARM template with `$schema`, `contentVersion`, and nested security rules.

### 💻 Azure CLI Export
Generates `az network nsg rule create` commands — one per rule, ready to paste into a terminal.

### ⚡ PowerShell Export
Generates `Add-AzNetworkSecurityRuleConfig` commands piped to `Set-AzNetworkSecurityGroup`.

### 📊 CSV Export
Generates a CSV file with one row per rule and proper field escaping. Multi-value fields (e.g. multiple address prefixes) use semicolons as delimiters within cells. CSV export does not include NSG metadata (name, location) — only rule data.

### 🔄 Flush Connection Toggle

The export modal includes a **"Flush existing connections on update"** checkbox. When enabled:
- **BICEP:** emits `flushConnection: true`
- **ARM JSON:** emits `"flushConnection": true`
- **PowerShell:** adds `-FlushConnection` parameter
- **CLI:** includes a comment noting the flush connection limitation

This forces existing connections to re-evaluate against updated rules rather than maintaining existing session state.

### 🏷️ ASG Export Support

Application Security Group references are correctly emitted across all 6 export formats. Each format uses the appropriate syntax for ASG references (e.g. BICEP uses `applicationSecurityGroups`, Terraform uses `source_application_security_group_ids`).

### 📊 Diff View
Compares original imported rules against current state using summary lines:

```js
function generateDiffHtml() {
  const before = rulesToSummaryLines(originalRules);
  const after = rulesToSummaryLines(currentRules);
  // Line-by-line comparison with +/- highlighting
}
```

**💡 Technique:** One internal data model → multiple output generators. Adding a new export format only requires writing one new function.

---

## 🔄 Flow Diagram — Visual Rule Summary

The firewall shield diagram counts rules by direction and action:

```js
const inAllow  = rules.filter(r => r.direction === 'Inbound'  && r.access === 'Allow').length;
const inDeny   = rules.filter(r => r.direction === 'Inbound'  && r.access === 'Deny').length;
const outAllow = rules.filter(r => r.direction === 'Outbound' && r.access === 'Allow').length;
const outDeny  = rules.filter(r => r.direction === 'Outbound' && r.access === 'Deny').length;
```

Layout: `Internet → [Allow/Deny lanes] → 🛡️ NSG Shield → [Allow/Deny lanes] → Workloads`

Deny lanes auto-hide when count is zero. Built with pure CSS flexbox — no canvas or SVG.

---

## 📝 Audit Log — Full Change Tracking

Every action is logged with structured metadata:

```js
function logAudit(action, details, meta = {}) {
  auditLog.push({
    time: new Date().toISOString(),
    action,    // e.g. "Add Rule", "Edit Rule", "Delete Rule"
    details,   // Human-readable summary
    meta       // Structured data: rule properties, before/after diffs
  });
}
```

### Per-Rule Metadata

The `ruleToMeta()` helper captures a complete snapshot of any rule:

```js
function ruleToMeta(r) {
  return {
    name: r.name, priority: r.priority, direction: r.direction,
    access: r.access, protocol: r.protocol,
    sourceAddress: r.sourceAddressPrefix || r.sourceAddressPrefixes?.join(','),
    sourcePort: r.sourcePortRange || r.sourcePortRanges?.join(','),
    destAddress: r.destinationAddressPrefix || r.destinationAddressPrefixes?.join(','),
    destPort: r.destinationPortRange || r.destinationPortRanges?.join(','),
    description: r.description
  };
}
```

### CSV Export

Multi-rule actions (like "Add All Defaults") export **one row per rule** with 14 columns, giving full traceability.

---

## 🎛️ Accordion Sections — Lazy Rendering

Sections use a `sectionMap` object that maps keys to toggle/body element IDs:

```js
const sectionMap = {
  rules:    { toggle: 'rulesToggle',    body: 'rulesBody' },
  analysis: { toggle: 'analysisToggle', body: 'analysisBody' },
  ports:    { toggle: 'portsToggle',    body: 'portsBody' },
  // ...
};
```

When a section is expanded, it triggers content rendering on-demand:

```js
function toggleSection(key) {
  const { body } = sectionMap[key];
  body.classList.toggle('open');
  if (key === 'ports' && body.classList.contains('open')) renderPorts();
  if (key === 'tags'  && body.classList.contains('open')) renderServiceTags();
}
```

**💡 Technique:** Deferred rendering — heavy content like the ports table (100+ entries) only renders when the user actually opens that section, keeping initial load fast.

### 🖱️ Port & Service Tag Context Menus

Clicking a port card or service tag opens a **context menu** at the cursor position, letting you create a new rule with that value pre-filled:

```js
// Position the menu at the click location
const menu = document.createElement('div');
menu.style.top = `${event.clientY}px`;
menu.style.left = `${event.clientX}px`;
menu.innerHTML = `
  <div onclick="createRuleFromPort('${port}', 'destination')">📥 Destination port</div>
  <div onclick="createRuleFromPort('${port}', 'source')">📤 Source port</div>
`;
```

The same pattern is used for Azure Service Tags, where clicking offers "📤 Source address" or "📥 Destination address" options. The context menu is dismissed by clicking anywhere else on the page.

**💡 Technique:** Shared CSS class (`.port-context-menu`) and a one-time click listener on `document` for auto-dismissal — keeps the code DRY across both port and tag menus.

---

## ⌨️ Keyboard Shortcuts & Command Palette

The app includes a VS Code-style command palette (`Ctrl+K`):

```js
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
    e.preventDefault();
    openCommandPalette();
  }
});
```

Commands are filtered as you type, and arrow keys + Enter navigate the list — all built with vanilla JavaScript event handling.

---

## 📏 Resizable Table Columns

Column headers support click-and-drag resizing:

```js
header.addEventListener('mousedown', (e) => {
  const startX = e.pageX;
  const startWidth = header.offsetWidth;
  document.addEventListener('mousemove', onMouseMove);
  document.addEventListener('mouseup', onMouseUp);
});
```

**💡 Technique:** Pointer event capture during drag, released on mouseup — a common pattern for custom resize handles without any library.

---

## 🔗 Expression Resolution Engine

Real-world IaC templates rarely use hardcoded values — they reference parameters, variables, and use string interpolation. The expression resolution engine detects and resolves these automatically.

### Building the Symbol Table

During import, each parser scans for declarations alongside NSG rules:

```js
function buildSymbolTable(content, format) {
  const symbols = {};
  // Bicep: param vnetPrefix string = '10.0.0.0/16'
  // ARM:   "parameters": { "vnetPrefix": { "defaultValue": "10.0.0.0/16" } }
  // TF:    variable "vnet_prefix" { default = "10.0.0.0/16" }
  return symbols;  // { vnetPrefix: '10.0.0.0/16', ... }
}
```

The symbol table is built per-format since each IaC language has its own declaration syntax.

### Resolving Expressions

After parsing rules, each field value is checked against the symbol table:

```js
function resolveExpression(value, symbols) {
  // Direct reference: 'vnetPrefix' → '10.0.0.0/16'
  if (symbols[value]) return { resolved: symbols[value], expr: value };
  
  // String interpolation: '${prefix}/24' → '10.0.0.0/24'
  const interpolated = value.replace(/\$\{(\w+)\}/g, (_, name) => symbols[name] || _);
  if (interpolated !== value) return { resolved: interpolated, expr: value };
  
  return { resolved: value, expr: null };  // No expression found
}
```

### Expression Metadata — The Round-Trip Secret

When an expression is resolved, the original expression is stored as metadata on the rule:

```js
rule.sourceAddressPrefix = '10.0.0.0/16';        // Resolved value (for display and editing)
rule._expr_sourceAddressPrefix = 'vnetPrefix';    // Original expression (for export)
```

This dual-storage approach means:
- **Display & editing** use the resolved literal value — users see real IPs, not expressions
- **Export** checks for `_expr_*` metadata and re-emits the original expression with its declaration
- **User edits break the link** — if a user changes a resolved value, the `_expr_*` metadata is removed

### The Resolution Modal

When some expressions can't be auto-resolved (e.g., a parameter with no default value), the app shows a resolution modal:

- Text fields for manual value entry
- A mini drop zone for companion files (`.bicepparam`, `.tfvars`, `parameters.json`)
- A "Skip" option that keeps raw expressions in the rule (shown with ⚠️ indicator)

### Inline Values Toggle

The export modal offers an "Inline all values" checkbox. When checked:
- All `_expr_*` metadata is ignored
- Exports use literal values only — no parameter declarations
- Companion parameter files are not generated

**💡 Technique:** The expression engine is a compiler-like pipeline: **parse → build symbol table → resolve references → store metadata → round-trip on export**. This pattern handles all three IaC formats with the same architecture.

---

## 🔄 Format Conversion — The Hidden Superpower

One of the most powerful features of the editor isn't obvious from any single button or menu — it's a natural consequence of the architecture.

### The Universal Rule Model

Every imported rule — whether from Bicep, ARM JSON, Terraform, or CSV — is normalised to the same internal JavaScript object:

```js
{
  name: 'AllowHTTPS',
  priority: 100,
  direction: 'Inbound',
  access: 'Allow',
  protocol: 'Tcp',
  sourceAddressPrefix: '*',
  destinationAddressPrefix: '10.0.1.0/24',
  destinationPortRange: '443',
  description: 'Allow HTTPS traffic'
}
```

This means:
- **Import Bicep → Export Terraform** — migrate your IaC tool
- **Import ARM JSON → Export Bicep** — modernise legacy templates
- **Import Terraform → Export Azure CLI** — generate one-off deployment scripts
- **Import CSV → Export ARM JSON** — turn a spreadsheet into infrastructure code

### Companion File Generation

When exporting IaC formats with parameterised values, the editor generates companion files:

| Export Format | Companion File | Purpose |
|--------------|---------------|---------|
| Bicep | `.bicepparam` | Parameter values using `using` syntax |
| ARM JSON | `parameters.json` | Parameter values JSON for `az deployment` |
| Terraform | `.tfvars` | Variable values for `terraform apply` |

### 24 Format Combinations

4 import formats × 6 export formats = 24 possible conversions — all handled automatically through the universal rule model. No special "conversion" code exists; it's simply a side effect of good architecture.

**💡 Technique:** The "adapter pattern" at work — each parser is an input adapter, each exporter is an output adapter, and the internal rule model is the universal interface. Adding a new format (import or export) only requires writing one new adapter function.

---

## 🧩 Key Design Patterns Summary

| Pattern | Where Used | Why |
|---------|-----------|-----|
| 🎨 **CSS Custom Properties** | Theme system | One attribute change re-themes everything |
| 📦 **Single source of truth** | `nsgState.rules` array | All views derive from one canonical dataset |
| 🔄 **Lazy rendering** | Accordion sections | Only render content when the user needs it |
| 💾 **Cache invalidation** | Analysis engine | Avoid re-computation via revision counter |
| 🔀 **Format adapters** | Export system | One data model, many output formats |
| 🧮 **Bitwise arithmetic** | CIDR calculator | Same math as real network hardware |
| 📊 **First-match evaluation** | What-If simulator | Mirrors actual Azure NSG behavior |
| 🔍 **Set-wise coverage** | Shadow/conflict detection | Mathematically correct overlap analysis |
| 📝 **Structured metadata** | Audit log | Enables both UI rendering and CSV export |
| 🔗 **Expression resolution** | Import parsers | Compiler-like pipeline: parse → resolve → store metadata → round-trip |
| 🔄 **Format conversion** | Import/Export system | Universal rule model enables any-to-any format conversion |
| 🚫 **Zero dependencies** | Entire app | No npm, no build step, no CDN — just open the file |

---

> *Built with ❤️ using GitHub Copilot CLI — zero frameworks, pure web fundamentals*
