# 🎯 NSG Rule Editor — End-to-End DevOps Talk Track

> **From code change to production in minutes — powered by GitHub & Copilot**

---

## 🗺️ The Journey at a Glance

```
💡 Idea  →  🤖 Code with Copilot  →  🌿 Branch  →  📋 PR  →  🔍 Review  →  ✅ Merge  →  🚀 Deploy  →  🌐 Live
```

---

## Step 1 — 💡 Identify the Change

> *"It all starts with a need — a bug report, a feature request, or an improvement."*

- GitHub **Issue Templates** provide structured intake forms
- 🐛 **Bug reports** capture browser, steps to reproduce, and severity
- ✨ **Feature requests** capture the problem, proposed solution, and priority
- Issues are tracked, labelled, and linked to pull requests for full traceability

**🎤 Demo point:** *"Go to Issues → New Issue — notice the structured templates, not a blank text box."*

---

## Step 2 — 🤖 Code with GitHub Copilot

> *"Instead of writing every line from scratch, I collaborate with an AI pair programmer."*

- **GitHub Copilot CLI** assists directly in the terminal — no IDE needed
- Copilot understands the full codebase context and makes surgical changes
- It suggests code, explains logic, and even runs tests
- Every commit includes a `Co-authored-by: Copilot` trailer for attribution

**🎤 Demo point:** *"Watch me describe the change in natural language and Copilot implements it — including edge cases I hadn't considered."*

### Recent Features Built with Copilot
- **Application Security Group (ASG) support** — rules can reference ASGs instead of IP addresses, with a mode toggle in the editor and full round-trip across all import/export formats
- **CSV import/export** — drag-and-drop CSV files for import; new CSV tab in the export modal with proper escaping and semicolon-delimited multi-value fields
- **Service tag deprecation warnings** — deprecated tags (`AzureUpdateDelivery`, `AzureFrontDoor.FirstParty`, `AzureContentDelivery`) flagged with strikethrough and non-blocking warning toasts
- **Flush connection toggle** — export option to emit `flushConnection` in BICEP, ARM JSON, and PowerShell, forcing existing connections to re-evaluate
- **Rule hit count documentation** — info box in the analysis section linking to NSG Flow Logs and Traffic Analytics in Azure Monitor
- **Enhanced search** — the search bar now filters rules across all fields (ports, addresses, protocol)
- **Context menus** — click any port or service tag to create a rule with that value pre-filled
- **Expression resolution engine** — parameters, variables, and string interpolation in Bicep/ARM/Terraform are auto-detected, resolved from file context, and round-tripped through export with `_expr` metadata
- **IaC format conversion** — import in any format, export in any other format (Bicep → Terraform, ARM → Bicep, etc.) via a universal internal rule model
- **Companion parameter files** — Bicep exports generate `.bicepparam`, ARM exports generate `parameters.json`, Terraform exports generate `.tfvars`
- **Inline values toggle** — one checkbox to switch between parameterised and literal value exports
- **Auto-save with restore UX** — editor state persists to localStorage; resume/start-fresh banner on page reload
- **Duplicate rule detection** — fingerprint-based analysis flags rules with identical traffic criteria

### 🔄 IaC Format Conversion Demo

> *"This isn't just an editor — it's a universal IaC translator for NSG rules."*

**🎤 Demo point:** *"I'll import this Bicep file with parameterised values... notice how the expression resolution engine detected 3 parameters and resolved them automatically from their defaults. Now watch — I'll export as Terraform. The rules are identical, but the output is valid HCL with variable blocks. We just converted Bicep to Terraform without writing a single line of code."*

**🎤 Demo point:** *"See this checkbox — 'Inline all values'? When I check it, the export uses literal IP addresses instead of parameter references. When I uncheck it, the original expressions round-trip back. This is expression intelligence."*

**🎤 Demo point:** *"Notice the companion file tab — alongside the Terraform export, it generated a `.tfvars` file with the parameter values. Same for Bicep (`.bicepparam`) and ARM (`parameters.json`). Ready to deploy."*

---

## Step 3 — 🌿 Create a Feature Branch

> *"We never push directly to production. Every change starts on its own branch."*

```bash
git checkout -b feature/my-new-feature
```

- **GitHub Flow** branching strategy — simple and effective
- `main` is always deployable
- Feature branches are short-lived and focused
- **Branch protection rules** enforce this — direct pushes to `main` are blocked

**🎤 Demo point:** *"Notice you can't push to main directly — the branch protection rules prevent it."*

---

## Step 4 — 📋 Open a Pull Request

> *"A PR isn't just a code change — it's a conversation, a review, and a quality gate."*

- Push the branch → open a PR on GitHub
- **PR Template** auto-populates with a structured checklist:
  - ✅ Type of change (bug fix, feature, refactor)
  - ✅ Testing completed (local, light/dark theme, no console errors)
  - ✅ Screenshots for visual changes
- The PR links back to the original issue for traceability

**🎤 Demo point:** *"Look at how the PR template guides the developer — every PR follows the same quality standard."*

---

## Step 5 — 🔍 Code Review

> *"Every change is reviewed before it reaches production — by humans and AI."*

### 👤 Human Review
- Branch protection requires **at least 1 approving review**
- Stale reviews are automatically dismissed if new commits are pushed
- Reviewers can comment, request changes, or approve

### 🤖 Copilot Code Review *(Available)*
- AI-powered review catches bugs, security issues, and logic errors
- Provides inline suggestions directly on the PR
- Complements human review — doesn't replace it

**🎤 Demo point:** *"Two layers of review — AI catches the obvious issues, humans focus on design and business logic."*

---

## Step 6 — ✅ Merge to Main

> *"Once approved, merging is a single click — and it triggers everything downstream."*

- **Merge** the PR (merge commit preserves full history)
- Feature branch is automatically deleted (clean repo)
- The merge commit on `main` triggers the CI/CD pipeline

**🎤 Demo point:** *"One click to merge — watch what happens next..."*

---

## Step 7 — 🚀 GitHub Actions Deploys to Azure

> *"No manual deployment. No FTP. No scripts to remember. It just happens."*

### The Pipeline (`deploy.yml`)

```
📦 Checkout code
   ↓
🔐 Azure OIDC Login (passwordless — no secrets stored!)
   ↓
☁️ Deploy to Azure Static Web Apps (SWA CLI)
   ↓
🌐 Live at production URL
```

### Key Technologies
| Component | Technology | Why It's Great |
|-----------|-----------|---------------|
| 🔐 **Authentication** | OIDC / Federated Credentials | No passwords or keys — token-based trust |
| ⚡ **Runner** | Self-hosted Windows runner | Runs on your own infrastructure |
| 📦 **Hosting** | Azure Static Web Apps | Serverless, fast, cost-effective |
| 🔄 **Trigger** | Push to `main` | Fully automated, zero manual steps |

**🎤 Demo point:** *"Notice there are no passwords anywhere — OIDC uses federated trust between GitHub and Azure. This is enterprise-grade security."*

---

## Step 8 — 🌐 Live in Production

> *"Within about a minute, the change is live and accessible worldwide."*

- App is served from **Azure Static Web Apps**
- URL: `https://nsgeditor.djtools.co.nz/`
- **Deployment badge** in the README shows real-time build status
- Full audit trail: Issue → Branch → PR → Merge → Deploy

**🎤 Demo point:** *"Refresh the browser — the change is already live. Check the README badge — green means the latest deploy succeeded."*

---

## 🛡️ Safety Nets Throughout

| Protection | What It Does |
|-----------|-------------|
| 🔒 **Branch protection** | No direct pushes to `main` |
| 📋 **PR template** | Standardised quality checklist |
| 👥 **Required reviews** | At least 1 approval before merge |
| 🔄 **Stale review dismissal** | New commits invalidate old approvals |
| 🤖 **Copilot co-authoring** | AI-assisted code with full attribution |
| 🚀 **Automated deployment** | No human error in the deploy process |
| 🔐 **OIDC authentication** | Passwordless, no stored secrets |

---

## 📊 The Full Picture

```
      📝                  🌿                  💻
+---------------+   +---------------+   +---------------+
|    Issue      |-->|    Branch     |-->|     Code      |
|   (GitHub)    |   |    (Git)      |   |   (Copilot)   |
+---------------+   +---------------+   +-------+-------+
                                                 |
                                                 v
      🌐                  🚀                  📋
+---------------+   +---------------+   +---------------+
|    Live!      |<--|    Deploy     |<--|      PR       |
|   (Azure)     |   |   (Actions)   |   |   (Review)    |
+---------------+   +---------------+   +---------------+
```

---

## 💬 Key Talking Points

1. **"Zero to production in minutes"** — from idea to live deployment, the entire process is automated and governed
2. **"AI-assisted, human-approved"** — Copilot writes code, humans review it — best of both worlds
3. **"No secrets, no passwords"** — OIDC federated credentials mean nothing sensitive is stored
4. **"Every change is traceable"** — from issue to deployment, there's a complete audit trail
5. **"Branch protection enforces quality"** — you literally cannot skip the review process
6. **"ASG support closes the enterprise gap"** — real-world NSGs use Application Security Groups, and now the editor handles them end-to-end
7. **"Six export formats"** — BICEP, ARM JSON, Terraform, CLI, PowerShell, and now CSV — covering every workflow from IaC to spreadsheets
8. **"Proactive deprecation warnings"** — the tool warns you about deprecated service tags before you deploy, avoiding surprises in production
9. **"Flush connections on update"** — a critical option for security-sensitive deployments where existing sessions must re-evaluate against new rules
10. **"Import any format, export any format"** — 4 import formats × 6 export formats = 24 conversion paths, powered by a universal internal rule model
11. **"Expression intelligence"** — parameters and variables aren't just imported as raw text — they're detected, resolved, and intelligently round-tripped through export
12. **"100% no-code"** — ~4000+ lines of production JavaScript, built entirely through natural language conversation with GitHub Copilot CLI
13. **"Auto-save protects your work"** — browser storage ensures you never lose progress, with a clean resume/start-fresh UX on page reload

---

> *Built with ❤️ using GitHub Copilot CLI, GitHub Actions, and Azure*
>
> **Version:** v1.0.0-beta
