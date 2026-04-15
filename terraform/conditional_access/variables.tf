################################################################################
# Variables — Zero Trust Conditional Access Stack
################################################################################

variable "policy_state" {
  description = "Deployment state for all CA policies. Use 'enabledForReportingButNotEnforced' to audit before enforcing."
  type        = string
  default     = "enabledForReportingButNotEnforced"

  validation {
    condition     = contains(["enabled", "disabled", "enabledForReportingButNotEnforced"], var.policy_state)
    error_message = "Must be 'enabled', 'disabled', or 'enabledForReportingButNotEnforced'."
  }
}

variable "break_glass_group_name" {
  description = "Display name of the break-glass/emergency-access Entra ID security group. Always excluded from enforcement policies."
  type        = string
  default     = "CA-Exclusion-BreakGlass"
}

variable "service_accounts_group_name" {
  description = "Display name of the service accounts security group. Excluded from device-compliance policies."
  type        = string
  default     = "CA-Exclusion-ServiceAccounts"
}

variable "privileged_role_ids" {
  description = "List of Entra ID directory role template IDs to target in the admin MFA policy."
  type        = list(string)
  # Defaults: Global Admin, Security Admin, Privileged Role Admin, Conditional Access Admin
  default = [
    "62e90394-69f5-4237-9190-012177145e10", # Global Administrator
    "194ae4cb-b126-40b2-bd5b-6091b380977d", # Security Administrator
    "e8611ab8-c189-46e8-94e1-60213ab1f814", # Privileged Role Administrator
    "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9", # Conditional Access Administrator
  ]
}

variable "sensitive_app_ids" {
  description = "List of application IDs to apply the 8-hour sign-in frequency policy."
  type        = list(string)
  # Replace with your tenant's sensitive app object IDs
  default = []
}
