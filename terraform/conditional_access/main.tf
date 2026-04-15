################################################################################
# Zero Trust Conditional Access Policy Stack
# Deploys 11 baseline policies for M365 Business Premium tenants
# Compatible with: Entra ID P1/P2, GCC Commercial, GCC High (adjust endpoints)
#
# Author : Ekaette Q. Umoh — ekaetteumoh.cloud
# Tested : Terraform >= 1.5 | azuread provider >= 2.47
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azuread" {
  # Credentials sourced from env vars or managed identity at runtime:
  # ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
  # For GCC High: set environment = "usgovernment"
}

################################################################################
# DATA — resolve well-known group/role IDs at plan time
################################################################################

data "azuread_group" "break_glass" {
  display_name     = var.break_glass_group_name
  security_enabled = true
}

data "azuread_group" "service_accounts" {
  display_name     = var.service_accounts_group_name
  security_enabled = true
}

################################################################################
# POLICY 01 — Require MFA for all users
################################################################################

resource "azuread_conditional_access_policy" "require_mfa_all_users" {
  display_name = "CA001 - Require MFA for All Users"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [
        data.azuread_group.break_glass.id,
        data.azuread_group.service_accounts.id,
      ]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = ["all"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

################################################################################
# POLICY 02 — Block legacy authentication
################################################################################

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = "CA002 - Block Legacy Authentication"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = [
      "exchangeActiveSync",
      "other",
    ]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

################################################################################
# POLICY 03 — Require compliant or hybrid-joined device for corporate apps
################################################################################

resource "azuread_conditional_access_policy" "require_compliant_device" {
  display_name = "CA003 - Require Compliant Device for Corporate Apps"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [
        data.azuread_group.break_glass.id,
        data.azuread_group.service_accounts.id,
      ]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = ["browser", "mobileAppsAndDesktopClients"]
  }

  grant_controls {
    operator = "OR"
    built_in_controls = [
      "compliantDevice",
      "domainJoinedDevice",
    ]
  }
}

################################################################################
# POLICY 04 — Require MFA for Azure management (portal, CLI, ARM)
################################################################################

resource "azuread_conditional_access_policy" "require_mfa_azure_mgmt" {
  display_name = "CA004 - Require MFA for Azure Management"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      # Windows Azure Service Management API
      included_applications = ["797f4846-ba00-4fd7-ba43-dac1f8f63013"]
    }
    client_app_types = ["all"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

################################################################################
# POLICY 05 — Require MFA for privileged roles (Global Admin, Security Admin, etc.)
################################################################################

resource "azuread_conditional_access_policy" "require_mfa_admins" {
  display_name = "CA005 - Require MFA for Privileged Roles"
  state        = var.policy_state

  conditions {
    users {
      included_roles  = var.privileged_role_ids
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = ["all"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

################################################################################
# POLICY 06 — Block access from high-risk sign-ins (requires P2)
################################################################################

resource "azuread_conditional_access_policy" "block_high_risk_signin" {
  display_name = "CA006 - Block High Risk Sign-Ins"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = ["all"]
    sign_in_risk_levels = ["high"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

################################################################################
# POLICY 07 — Require password change for high-risk users (requires P2)
################################################################################

resource "azuread_conditional_access_policy" "high_risk_user_pwd_change" {
  display_name = "CA007 - Require Password Change for High Risk Users"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = ["all"]
    user_risk_levels = ["high"]
  }

  grant_controls {
    operator          = "AND"
    built_in_controls = ["mfa", "passwordChange"]
  }
}

################################################################################
# POLICY 08 — Restrict access from unknown/untrusted locations for guests
################################################################################

resource "azuread_conditional_access_policy" "guest_mfa_external" {
  display_name = "CA008 - Require MFA for Guest and External Users"
  state        = var.policy_state

  conditions {
    users {
      included_guests_or_external_users {
        guest_or_external_user_types = ["internalGuest", "b2bCollaborationGuest", "b2bCollaborationMember"]
        tenant_filter {
          mode       = "include"
          tenants    = [] # leave empty to apply to all external tenants
        }
      }
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types = ["all"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

################################################################################
# POLICY 09 — Require MFA for device registration
################################################################################

resource "azuread_conditional_access_policy" "require_mfa_device_registration" {
  display_name = "CA009 - Require MFA for Device Registration"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_user_actions = ["urn:user:registerdevice"]
    }
    client_app_types = ["all"]
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

################################################################################
# POLICY 10 — App protection policy required for mobile (BYOD)
################################################################################

resource "azuread_conditional_access_policy" "require_app_protection_mobile" {
  display_name = "CA010 - Require App Protection Policy on Mobile"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_applications = ["All"]
    }
    client_app_types    = ["mobileAppsAndDesktopClients"]
    platforms {
      included_platforms = ["android", "iOS"]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["approvedApplication", "compliantApplication"]
  }
}

################################################################################
# POLICY 11 — Sign-in frequency: re-auth every 8h for sensitive apps
################################################################################

resource "azuread_conditional_access_policy" "signin_frequency_sensitive" {
  display_name = "CA011 - Sign-In Frequency 8h for Sensitive Apps"
  state        = var.policy_state

  conditions {
    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.break_glass.id]
    }
    applications {
      included_applications = var.sensitive_app_ids
    }
    client_app_types = ["all"]
  }

  session_controls {
    sign_in_frequency                            = 8
    sign_in_frequency_period                     = "hours"
    sign_in_frequency_authentication_type        = "primaryAndSecondaryAuthentication"
    sign_in_frequency_interval                   = "timeBased"
    persistent_browser_session_is_enabled        = false
  }
}
