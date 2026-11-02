# Ekaette Q. Umoh | Cloud Security Portfolio

[![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com)
[![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonaws&logoColor=white)](https://aws.amazon.com)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Microsoft Sentinel](https://img.shields.io/badge/Microsoft_Sentinel-0078D4?style=flat&logo=microsoftazure&logoColor=white)](https://learn.microsoft.com/azure/sentinel)

Cloud engineer with a security focus. I build infrastructure, automate the toil, then make sure it's hardened — currently at IL5 across Azure Government and AWS GovCloud. This repo is a working record of that: real deployments, real debugging, and documented decisions.

> **About this repo.** This is a write-up index, not a codebase. Each entry below is a platform I designed and built, documented down to the decisions and the bugs. Most of the source lives in private repositories — some mirror patterns from cleared environments, some are simply not hardened for publication yet. Where code is public, the repo is linked. I'm glad to walk through any of the private work in detail.

---

## Core Competencies

| Domain | Tools & Technologies |
|---|---|
| **Identity & Access** | Entra ID · PIM · Conditional Access · ABAC · App Registrations · MFA · CAC/PKI |
| **Cloud Platforms** | Azure Government · AWS GovCloud · Azure · AWS · M365 GCC High · Multi-tenant administration |
| **Infrastructure as Code** | Terraform · `azuread` · `azurerm` · `aws` providers · Remote state + locking |
| **CI/CD** | GitLab CI · GitLab administration & migration · GitHub Actions · OIDC federation |
| **Automation** | PowerShell · Python · Microsoft Graph API · Azure Automation · REST APIs |
| **Security & Compliance** | DISA STIG · Microsoft Sentinel · KQL · Checkov · Trivy · NIST 800-171 · NIST 800-53 · FedRAMP High · IL4/IL5 · DoD 8570 |
| **Containers & Orchestration** | ECS Fargate · EKS · ECR · Docker · ArgoCD · Kustomize · Kubernetes |
| **Observability** | Log Analytics · Azure Monitor · AMA · rsyslog · CloudWatch · Workbooks |

---

## Project Index

| Project | Status | Code | Stack |
|---|---|---|---|
| [Azure DevSecOps Pipeline](#-azure-devsecops-pipeline) | Built | **Public** | Terraform · Checkov · OIDC · Sentinel |
| [Azure Cowrie SSH Honeypot](#-azure-cowrie-ssh-honeypot) | Built | Private | Terraform · Sentinel · KQL · AMA |
| [AWS DevSecOps Pipeline](#-aws-devsecops-pipeline) | Built | Private | Terraform · Checkov · OIDC · AWS Config |
| [AWS Container Platform — ECS Fargate](#-aws-container-platform--ecs-fargate) | Built | Private | Terraform · ECS · ECR · ALB · IAM |
| [Zero Trust Conditional Access Stack](#-zero-trust-conditional-access-stack) | Built | Private | Terraform · Entra ID · M365 |
| [User Lifecycle Automation](#-user-lifecycle-automation) | Built | Private | PowerShell · Graph API |
| [Sentinel Threat Detection Rules](#-sentinel-threat-detection-rules) | Built | Private | KQL · Microsoft Sentinel |
| [ekaetteumoh.cloud](#-ekaetteumohcloud) | Live | Private | Azure Functions · Node.js · DNS |
| [Secure EKS Platform](#-secure-eks-platform--gitops--runtime-defense) | Paused | Private | EKS · ArgoCD · Kustomize · Trivy |

---

## Projects

### ✅ Azure DevSecOps Pipeline
**Stack:** Terraform · Checkov · GitHub Actions · OIDC Federation · Azure RBAC · Microsoft Sentinel · Defender for Storage

**Repo:** [ekaumoh/devsecops-azure-pipeline](https://github.com/ekaumoh/devsecops-azure-pipeline) — public

Shift-left DevSecOps pipeline that gates every Terraform deployment behind a Checkov security scan. Insecure code is blocked from merging via GitHub branch protection — hard enforcement, not advisory. Authentication uses OIDC federation between GitHub Actions and Entra ID: no stored secrets, no client credentials to rotate. Service principal is scoped to the deployment resource group only, not the subscription. Runtime coverage via Defender for Storage and Microsoft Sentinel unified with Defender XDR.

**What it demonstrates:**
- Checkov validates 11 controls per run; 8 enforced, 3 soft-failed with documented justification — a security engineering decision, not a bypass
- OIDC federation: GitHub mints a short-lived token at runtime, Entra ID exchanges it for an Azure access token. Zero long-lived credentials
- Least-privilege RBAC: Contributor scoped to resource group only; Storage Blob Data Contributor on state account only
- `storage_use_azuread = true` and `use_azuread_auth = true` on the backend block required for key-free state auth; the provider env var alone doesn't propagate to backend init
- Sentinel onboarded as Primary workspace to Defender XDR for unified incident queue

*Scope note: the deployed surface is intentionally small — a resource group and a hardened storage account. The engineering is in the gate, the federation, and the state handling, not the resource count.*

---

### ✅ Azure Cowrie SSH Honeypot
**Stack:** Terraform · Azure VM · Ubuntu 22.04 · Cowrie · rsyslog · AMA · Log Analytics · Microsoft Sentinel · KQL

Production-grade SSH honeypot deployed fully via Terraform — zero manual steps. Port 22 is open to the internet; real SSH admin access is on port 22222, key-only, restricted to a single `/32` source IP via NSG. Cowrie logs every credential attempt and attacker command, ships them to Log Analytics via rsyslog → AMA, and surfaces patterns through a Sentinel analytic rule and Azure Monitor Workbook with a live GeoIP attack map.

**What it demonstrates:**
- End-to-end Terraform deployment: VM, NSG, VNet, Managed Identity, Log Analytics, DCR, AMA extension, Sentinel onboarding, and a scheduled analytic rule in one `terraform apply`
- Log pipeline: Cowrie → rsyslog `imfile` → AMA TCP collector (port 28330) → Log Analytics
- KQL: credential spray detection, GeoIP attack map, top attacker IPs, top credentials attempted, attacker commands run
- Managed Identity as the authentication mechanism for AMA — no stored credentials anywhere
- Debugging through five real production bugs: missing pip entry point, wrong systemd path, virtualenv PATH, rsyslog permission errors, AMA identity failure — all resolved and documented

---

### ✅ AWS DevSecOps Pipeline
**Stack:** Terraform · Checkov · GitHub Actions · AWS OIDC · IAM · AWS Config · CloudTrail · GuardDuty

Full pass-fail-fix DevSecOps cycle captured in commit history. Pipeline gates every Terraform deployment behind Checkov — no AWS resource is created unless code passes compliance checks first. Authentication via OIDC with a trust policy scoped to a single repo. Post-deploy compliance monitoring via AWS Config with three managed rules watching for configuration drift, including manual console changes that bypass Terraform entirely.

**What it demonstrates:**
- Intentional misconfiguration → 7 Checkov findings → pipeline blocked → fix applied → green: the complete DevSecOps lifecycle visible in commit history
- OIDC IAM role scoped to a single repository, not all of GitHub
- Checkov skip annotations require inline placement inside the resource block — file-level comments are not parsed by the action
- AWS Config as the post-deploy layer: Checkov catches bad code; Config catches drift. Together they form defense in depth
- CloudTrail + GuardDuty enabled for full audit coverage

---

### ✅ AWS Container Platform — ECS Fargate
**Stack:** Terraform · ECS Fargate · ECR · ALB · VPC · IAM · CloudWatch · Docker

Production-pattern containerized application platform on ECS Fargate — entirely Terraform-provisioned, no manual console steps. Container tasks run exclusively in private subnets; the ALB is the only internet-reachable component. ECR has scan-on-push enabled and a lifecycle policy capping stored images. Two separate least-privilege IAM roles — task execution and task runtime — never combined.

**What it demonstrates:**
- SG-to-SG referencing: ECS security group ingress references the ALB SG ID, not a CIDR. Only ALB-originated traffic reaches containers
- IAM role separation: execution role has ECR pull + CloudWatch permissions; task role has zero AWS permissions — a compromised container gains nothing
- `assign_public_ip = false` on all ECS tasks — no direct internet path to the container layer
- ARM64/AMD64 build mismatch: `docker buildx build --platform linux/amd64` required on Apple Silicon for ECS Fargate compatibility
- Zero-downtime rolling deployment: 4 targets briefly (2 Healthy new + 2 Draining old), ALB routes only to healthy throughout

---

### ✅ Zero Trust Conditional Access Stack
**Stack:** Terraform · Entra ID (`azuread` provider) · M365 Business Premium / GCC High

11 Conditional Access policies deployed as code. Covers the full baseline: MFA enforcement, legacy auth block, device compliance gate, Azure management protection, privileged role MFA, risk-based policies (P2), guest MFA, device registration MFA, BYOD app protection, and 8-hour sign-in frequency for sensitive apps.

**What it demonstrates:**
- Policy-as-code: all 11 policies version-controlled and PR-reviewable before enforcement
- Variables-driven: break-glass group, service account exclusions, privileged role IDs, and sensitive app IDs are all inputs, not hardcoded
- Promotion path: deploy in `enabledForReportingButNotEnforced`, review sign-in logs, then enforce
- GCC High: `environment = "usgovernment"` on the provider block

---

### ✅ User Lifecycle Automation
**Stack:** PowerShell · Microsoft Graph API · Azure Automation (Managed Identity)

Automated offboarding runbook — all steps via Microsoft Graph, no portal clicks. Revokes sessions, blocks sign-in, removes licenses, removes from all groups, converts mailbox to shared, sets OOF, retires Intune devices, and posts a completion Adaptive Card to Teams.

**What it demonstrates:**
- Managed identity token retrieval from IMDS at runtime — zero stored credentials
- Graph API: `revokeSignInSessions`, `assignLicense`, `memberOf`, `managedDevices`, `mailboxSettings`
- `-WhatIf` dry-run mode gates every destructive operation
- GCC High: `graph.microsoft.us` sovereign endpoint

---

### ✅ Sentinel Threat Detection Rules
**Stack:** KQL · Microsoft Sentinel · Log Analytics · Entra ID SigninLogs

Three detection rules targeting identity-based attacks:

| Rule | MITRE ATT&CK | Signal |
|---|---|---|
| Credential Spray | T1110.003 | Single IP → many accounts → high failure rate within window |
| MFA Fatigue / Push Bombing | T1621 | High prompt volume per account → possible eventual approval |
| Impossible Travel | T1078 | Same account → physically impossible distance between sign-ins |

Each includes configurable thresholds, tuning notes, and RiskScore tiering logic.

---

### 🌐 ekaetteumoh.cloud
**Stack:** Azure Functions · Node.js · Azure DNS · Mailgun REST API · anime.js

Personal portfolio site and its backend. Contact form submissions hit an Azure Function (`submit_quote`) which authenticates to Mailgun via API key and delivers email. DNS is managed in Azure DNS with SPF and DKIM records verified. Frontend uses anime.js v4 loaded via native browser importmap — no bundler, no build step.

**What it demonstrates:**
- Azure Functions debugging: traced 401 → 500 → 200 through `authLevel` misconfiguration, wrong Mailgun key type (Key ID vs. secret), and CORS behavior
- Azure DNS gotcha: entering the full DKIM hostname in the Name field causes duplication — Azure appends the zone suffix automatically
- SendGrid → Mailgun migration required no changes to `index.html`; all changes were backend-only

→ [ekaetteumoh.cloud](https://ekaetteumoh.cloud)

---

### ⏸️ Secure EKS Platform — GitOps & Runtime Defense
**Stack:** Terraform · EKS 1.30 · ECR · ALB Controller · ArgoCD · Kustomize · GitHub Actions · Trivy · GuardDuty · Falco · CloudWatch

**Status: paused.** Phases 1–3 were built and verified; the cluster is torn down and the work is on hold. Terraform is ready to redeploy.

Production-pattern EKS platform split across three repositories by concern: infrastructure (Terraform), application (source + CI), and deployment (Kustomize manifests + ArgoCD). Every code change is gated by Trivy image scanning before reaching ECR. ArgoCD auto-syncs staging; production requires a PR approved via CODEOWNERS.

| Phase | Description | Status |
|---|---|---|
| 1 | VPC, EKS provisioning, IRSA, ALB Controller | ✅ Complete |
| 2 | Namespaces, PSS, ResourceQuota, LimitRange, Ingress | ✅ Complete |
| 3 | GitHub Actions CI, ECR, OIDC, ArgoCD, Trivy gate | ✅ Complete |
| 4 | Three-repo split, Kustomize overlays, GitOps hardening | ⏸️ Paused |
| 5 | GuardDuty EKS Protection, Falco runtime security | ⏸️ Paused |
| 6 | CloudWatch Container Insights, architecture diagram | ⏸️ Paused |

**What it demonstrated through Phase 3:**
- Worker nodes in private subnets; ALB in public subnets — only public-facing component, routes inbound traffic to pods
- GitHub OIDC → `sts:AssumeRoleWithWebIdentity`: pipeline role scoped to ECR push on `main` branch only, no long-lived keys
- Trivy `exit-code: 1` hard-blocks on CRITICAL/HIGH CVEs — image never reaches ECR if vulnerable
- Kustomize base has no `namespace:` field — the overlay's namespace transformer injects it at render time, preventing env values from leaking into the shared base
- Monorepo → three-repo split is the production maturity move once the GitOps loop is verified end to end

---

## Certification Roadmap

| Cert | Status |
|---|---|
| CompTIA A+ | ✅ Complete |
| CompTIA Security+ CE (DoD 8570 IAT II) | ✅ Complete |
| AZ-900 · Microsoft Azure Fundamentals | ✅ Complete |
| SC-300 · Microsoft Identity and Access Administrator | 🔄 In progress |
| AZ-500 · Microsoft Azure Security Engineer | 🔄 In progress |
| AZ-140 · Azure Virtual Desktop Specialty | 🔄 In progress |
| AWS Certified Security – Specialty | 📋 Planned |

---

## Environment Context

Current production work is at **IL5 in Azure Government and AWS GovCloud**. Much of the portfolio work above was built in, or adapted from, a **GCC High / GovCloud** M365 multi-tenant environment, with the remainder built in commercial Azure and AWS.

---

**Ekaette Q. Umoh** · Silver Spring, MD · Active TS/SCI