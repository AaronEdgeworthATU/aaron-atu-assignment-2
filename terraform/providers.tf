# -----------------------------------------------------------------------------
# providers.tf
# Configures HOW Terraform talks to AWS: which region, and which tags are
# stamped on every resource.
# -----------------------------------------------------------------------------

provider "aws" {
  # The region every resource is created in. It comes from a variable
  # (see variables.tf) so it is validated, and so Sentinel can inspect it in
  # the plan. eu-west-1 = Dublin, Ireland: this is the core of the
  # data-residency/sovereignty requirement.
  region = var.aws_region

  # default_tags are automatically added to EVERY resource this provider
  # creates. Tags give you ownership and data-classification metadata that
  # Sentinel policies can check (e.g. "sensitive data must stay in Ireland").
  default_tags {
    tags = {
      Organisation       = var.organisation
      Environment        = var.environment
      ManagedBy          = "Terraform"
      DataClassification = var.data_classification
      DataResidency      = "IE" # ISO country code for Ireland
    }
  }

  # ---------------------------------------------------------------------------
  # ZERO-COST / NO-CREDENTIALS PLANNING (optional)
  # The assignment only needs a `terraform plan`, not an apply. These settings
  # stop the provider from calling AWS to check credentials, so a plan can run
  # with dummy values (e.g. set AWS_ACCESS_KEY_ID=mock and
  # AWS_SECRET_ACCESS_KEY=mock as environment variables in HCP Terraform).
  # This only works because this config uses no "data" sources that read
  # from AWS. Remove these lines if you use a real AWS account.
  # ---------------------------------------------------------------------------
  skip_credentials_validation = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
