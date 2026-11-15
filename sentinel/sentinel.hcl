# -----------------------------------------------------------------------------
# sentinel.hcl
# The policy set configuration. HCP Terraform reads this file to learn which
# policies exist and how strictly each one is enforced.
#
# Enforcement levels:
#   advisory       - failure is only a warning; the run continues
#   soft-mandatory - failure blocks the run, but an org owner can override it
#   hard-mandatory - failure blocks the run; nobody can override it
# -----------------------------------------------------------------------------

policy "sovereignty" {
  source = "./sovereignty.sentinel"
  # Data leaving Irish jurisdiction is a legal/regulatory issue, not a
  # judgement call, so no override is allowed.
  enforcement_level = "hard-mandatory"
}

policy "encryption" {
  source = "./encryption.sentinel"
  # Unencrypted sensitive data is never acceptable.
  enforcement_level = "hard-mandatory"
}

policy "metadata" {
  source = "./metadata.sentinel"
  # IMDSv1 exposes AWS credentials to SSRF attacks.
  enforcement_level = "hard-mandatory"
}

policy "network" {
  source = "./network.sentinel"
  # Internet-exposed SSH is one of the most common causes of compromise.
  enforcement_level = "hard-mandatory"
}

policy "instance_type" {
  source = "./instance_type.sentinel"
  # A cost/capacity decision rather than a security one: blocked by default,
  # but an org owner may approve an exception (e.g. a one-off larger server).
  enforcement_level = "soft-mandatory"
}
