# cloud-security-portfolio

[![Azure](https://img.shields.io/badge/Azure-0078D4?style=flat&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io)
[![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell)
[![Microsoft 365](https://img.shields.io/badge/M365-D83B01?style=flat&logo=microsoftoffice&logoColor=white)](https://www.microsoft.com/microsoft-365)
[![Sentinel](https://img.shields.io/badge/Microsoft_Sentinel-0078D4?style=flat&logo=microsoftazure&logoColor=white)](https://learn.microsoft.com/azure/sentinel)

Infrastructure-as-code, automation runbooks, and security engineering artifacts from production M365/Azure environments. Built to be reusable, documented, and auditable.

> 💼 **Looking to engage?** Full service packages and pricing at [ekaetteumoh.cloud](https://ekaetteumoh.cloud/#packages)

---

## What's in this repo

| Folder | What it covers | Relevant package |
|---|---|---|
| [`terraform/conditional-access`](./terraform/conditional-access/) | Zero Trust CA policy stack — 11 policies, IaC-deployed | SecureFoundation |
| [`terraform/intune-compliance`](./terraform/intune-compliance/) | Device compliance baselines (Windows, macOS, iOS, Android) | SecureFoundation |
| [`powershell/user-lifecycle`](./powershell/user-lifecycle/) | Automated onboarding & offboarding via Graph API | Care Plan |
| [`powershell/license-management`](./powershell/license-management/) | License assignment, reporting, and reclamation | Care Plan |
| [`kql/sentinel-analytics`](./kql/sentinel-analytics/) | Threat detection rules for Microsoft Sentinel | SecureFoundation |
| [`kql/audit-log-queries`](./kql/audit-log-queries/) | M365 audit log KQL queries for compliance reporting | Care Plan |
| [`honeypot`](./honeypot/) | Terraform-deployed Cowrie SSH honeypot on Azure | — |

---

## Highlights

### 🔐 Zero Trust Conditional Access (Terraform)
Full 11-policy CA stack deployed as code against an Entra ID tenant. Covers MFA enforcement, device compliance, named location controls, and break-glass exclusions. Designed for M365 Business Premium / GCC High.

→ [`terraform/conditional-access/`](./terraform/conditional-access/)

### ⚙️ User Lifecycle Automation (PowerShell + Graph API)
Offboarding script that revokes sessions, removes licenses, converts to shared mailbox, blocks sign-in, and posts a summary to Teams — all via Microsoft Graph. No manual portal steps.

→ [`powershell/user-lifecycle/`](./powershell/user-lifecycle/)

### 📊 Sentinel Threat Detection (KQL)
Production-tested KQL analytics rules for credential spray detection, MFA fatigue attack identification, and impossible travel alerting. Includes both the analytic rule query and a workbook visualization query.

→ [`kql/sentinel-analytics/`](./kql/sentinel-analytics/)

---

## Environment context

Most of this work was developed in or adapted from a **GCC High / GovCloud** M365 multi-tenant environment. Where GCC High has endpoint differences (e.g., `graph.microsoft.us` vs `graph.microsoft.com`), those are noted inline in the code.

---

## Usage

Each subfolder has its own `README.md` with prerequisites, variable definitions, and deployment instructions. Nothing here requires paid tooling beyond an Azure/M365 subscription.

---

## Contact

**Ekaette Q. Umoh** — Cloud Security Engineer, Baltimore MD  
[ekaetteumoh.cloud](https://ekaetteumoh.cloud) · [admin@ekaetteumoh.cloud](mailto:admin@ekaetteumoh.cloud)
