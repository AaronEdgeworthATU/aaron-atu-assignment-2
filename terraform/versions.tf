# -----------------------------------------------------------------------------
# versions.tf
# Pins the Terraform CLI version and the providers this configuration may use.
# This is the first line of IaC SUPPLY CHAIN control: it says exactly WHERE
# providers come from and WHICH versions are acceptable.
# -----------------------------------------------------------------------------

terraform {
  required_version = "1.17.1"

  cloud {

    organization = "Aaron-L00205292"

    workspaces {
      name = "Terraform-Digital-Sovereignty-Assignment"
    }
  }

  required_providers {
    aws = {
      # "source" is the provider's registry address: <hostname>/<namespace>/<type>.
      # "hashicorp/aws" is shorthand for "registry.terraform.io/hashicorp/aws",
      # the official AWS provider published by HashiCorp. A Sentinel policy can
      # later check that only approved sources like this one are used.
      source = "hashicorp/aws"

      # "~> 6.0" means "any 6.x version, but never 7.0". The pessimistic
      # constraint operator (~>) lets you pick up bug fixes while blocking
      # major versions that may contain breaking changes.
      version = "~> 6.0"
    }
  }

  # ---------------------------------------------------------------------------
  # HCP Terraform integration (uncomment once you have an HCP org/workspace).
  # With this block, `terraform plan` runs remotely in HCP Terraform, which is
  # where Sentinel policies are evaluated against the plan.
  # ---------------------------------------------------------------------------
  # cloud {
  #   organization = "YOUR-HCP-ORG-NAME"
  #   workspaces {
  #     name = "atu-sovereignty-compliant"
  #   }
  # }
}

# NOTE: Running `terraform init` creates .terraform.lock.hcl. That file records
# the exact provider version chosen AND its cryptographic hashes, so every later
# init verifies it is downloading the identical, untampered provider binary.
# Commit it to Git; it is one of the assignment deliverables.
