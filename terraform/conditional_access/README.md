# Terraform · Zero Trust Conditional Access Stack

Deploys 11 baseline Conditional Access policies to an Entra ID tenant using Terraform. Designed for M365 Business Premium environments; tested against GCC High (adjust provider `environment` accordingly).

## Policies deployed

| ID | Policy | Enforcement |
|---|---|---|
| CA001 | Require MFA for all users | Grant — MFA |
| CA002 | Block legacy authentication | Grant — Block |
| CA003 | Require compliant or hybrid-joined device | Grant — Compliant OR Hybrid |
| CA004 | Require MFA for Azure management | Grant — MFA |
| CA005 | Require MFA for privileged roles | Grant — MFA |
| CA006 | Block high-risk sign-ins | Grant — Block (P2) |
| CA007 | Require password change for high-risk users | Grant — MFA + PwdChange (P2) |
| CA008 | Require MFA for guests and external users | Grant — MFA |
| CA009 | Require MFA for device registration | Grant — MFA |
| CA010 | Require app protection policy on mobile (BYOD) | Grant — App Protection |
| CA011 | 8-hour sign-in frequency for sensitive apps | Session control |

All policies exclude a **break-glass group** and a **service accounts group** by default — configure these in `variables.tf` before deploying.

## Prerequisites

- Terraform >= 1.5
- `hashicorp/azuread` provider ~> 2.47
- An app registration (or managed identity) with `Policy.ReadWrite.ConditionalAccess` and `Directory.Read.All` Graph permissions
- Two pre-existing security groups: break-glass exclusion group, service accounts exclusion group
- P2 licenses for policies CA006 and CA007 (risk-based)

## Deployment

```bash
# 1. Set credentials
export ARM_CLIENT_ID="<app-id>"
export ARM_CLIENT_SECRET="<secret>"
export ARM_TENANT_ID="<tenant-id>"

# 2. Initialize and plan in report-only mode first
terraform init
terraform plan -var="policy_state=enabledForReportingButNotEnforced"

# 3. Review sign-in logs for 1–2 weeks, then enforce
terraform apply -var="policy_state=enabled"
```

## GCC High note

Add `environment = "usgovernment"` to the provider block and ensure your Graph API calls target `graph.microsoft.us`.

## Related packages

This module is the IaC backbone of the **SecureFoundation** package at [ekaetteumoh.cloud](https://ekaetteumoh.cloud/#packages).
