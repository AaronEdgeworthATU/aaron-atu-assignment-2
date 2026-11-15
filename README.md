# aaron-atu-assignment-2
Terraform Digital Sovereignty Assignment - Ruth Lennon

## Overview
This repository is a Policy-as-Code framework for organisation L00205292. It uses Terraform and HashiCorp Sentinel, run through HCP Terraform, to enforce digital sovereignty for Ireland and infrastructure security rules. Non-compliant infrastructure is blocked at plan time, before anything is deployed. No real AWS resources are created: plans run with mock credentials, so the project costs nothing.

## Repository Structure
```
terraform/        Terraform configuration (.tf), .terraform.lock.hcl and tfplan
sentinel/         Sentinel policies and sentinel.hcl
sentinel/mocks/   Sentinel mock data downloaded from the passed and failed HCP runs
sentinel/logs/    Policy check logs from HCP Terraform
documentation/    Screenshots, evidence, technical report and LLM prompt log
```

## Development Approach
I began by generating a base Terraform stack to work from, which was established to successfully run 'terraform init' and 'terraform plan' before any Sentinel policies were implemented. Anthropic's Claude was used to generate the baseline files. When running 'terraform plan' there were versioning issues, so the required Terraform version was altered to allow any 1.17.x version. The project was then built up in stages, with each stage committed separately so the changes can be followed in the commit history.

## Infrastructure Design
**Compute and storage (main.tf):**
The main.tf file establishes an instance type of t3.micro to host the application called "web". The aws_instance contains a root_block_device to store the data required for hosting and configuring the AWS Web Instance. Separately there is an Elastic Block Store volume, named "data", that will contain the possibly sensitive data. On the "data" EBS volume, the encrypted attribute is set to "true". This ensures that the data stored on the aws_ebs_volume is separate from where the EC2 web OS and configuration is stored. The encryption is checked by "encryption.sentinel". The metadata_options block requires IMDSv2 tokens, meaning connections to the metadata service must possess an assigned session token first.

**Network (network.tf):**
Previously there was just one main subnet that had no Internet Gateway, so the whole subnet was private and inaccessible. It is now separated into a public subnet and 2 private subnets ("app" and "data"). The stack is based on a 3-tier architecture, similar to the previous assignment to keep things familiar. The inclusion of further subnets enhances security, invokes separation of concerns and limits the damage if one tier is compromised. All three subnets are in the one availability zone (eu-west-1a), so this does not remove a single point of failure.

A route table was added with an internet gateway, which makes the public subnet the only subnet with a route to the internet. The public subnet is currently empty and is reserved for a future load balancer. The "web" instance sits in the private "app" subnet, and its EBS volume is attached to it there, as an EBS volume is a disk and cannot be placed in a subnet on its own.

A security group was also added for the "data" tier, which only accepts PostgreSQL traffic from resources in the web security group, and allows no outbound traffic from the data tier.

## Sentinel Policies
Five Sentinel policies have been defined that will ensure a failed run if any of the rules defined are breached. The sentinel.hcl file sets "hard-mandatory" on 4 of the policies, meaning that if anything in the stack is in breach of the deployment rules HCP Sentinel will FAIL the stack plan/apply. On the HCP Terraform free plan only one policy could be set to mandatory, so in HCP sovereignty is hard-mandatory and the other four run as "advisory". The sentinel.hcl file records the intended enforcement levels.
- **sovereignty.sentinel:** The rules in this policy ensure that the resources are ONLY created in approved_regions = "eu-west-1", and that every availability zone is inside that region. Resources tagged with a DataClassification of "sensitive" or "confidential" are checked for their DataResidency tag. If the DataResidency is not "IE" then the policy will fail, as the data is not declared as under Irish jurisdiction.
- **encryption.sentinel:** The rules in this policy ensure that ALL EBS storage is encrypted at rest. There are three places a disk can be defined in Terraform, so all three are checked: the root_block_device on the aws_instance, any extra ebs_block_device on the instance, and the separate aws_ebs_volume "data". Each one must have encrypted = "true". If the root_block_device is missing completely the policy will also fail, as the AMI default could be unencrypted.
- **metadata.sentinel:** The rules in this policy ensure that every aws_instance requires IMDSv2 tokens, with http_tokens = "required" in the metadata_options block. If http_tokens is set to "optional", or the metadata_options block is missing, the policy will fail, as IMDSv1 would allow a plain GET request to retrieve the instance credentials (SSRF attack).
- **network.sentinel:** The rules in this policy ensure that SSH (port 22) is NOT open to the whole internet ("0.0.0.0/0"). Only port 443 (HTTPS) is approved to be open to the internet, any other port open to the internet will fail. The subnet and instance are also checked so that they do not assign public IP addresses automatically (map_public_ip_on_launch and associate_public_ip_address). Inbound rules can be written three different ways in Terraform, so all three are checked so the policy can't be avoided.
- **instance_type.sentinel:** The rules in this policy ensure that the aws_instance ONLY uses an approved instance type, approved_instance_types = "t3.micro", "t3.small" or "t3.medium". This is the one policy set to "soft-mandatory" in sentinel.hcl, as it is more of a cost decision than a security one, meaning an organisation owner can override a failure if a larger instance is needed.

## Digital Sovereignty Requirements

Region restrictions help to improve security as the policies can be centrally created and applied. This reduces the risk of replication or unintentional movement of sensitive data to regions outside of the prescribed jurisdiction, where it could be stored and accessed. This can prevent facilities or employees being compromised and data being stolen in locations where the EU or Ireland cannot enforce their laws. However, the policy only checks where resources are created at plan time, so backups, snapshots copied to other regions and administrative access from outside the EU would need further controls.

## Supply Chain Security

Controlling the versions prevents situations arising where vulnerabilities that are introduced in a version update get applied to sovereign or sensitive infrastructure without the explicit intention to upgrade to the new version. Likewise the versions cannot be rolled back to older versions that contain a vulnerability that was patched in the later versions the constraint enforces. In this project the provider source is restricted to "hashicorp/aws" with version "~> 6.0" in versions.tf, and the .terraform.lock.hcl file records the checksums of the provider so a tampered download would be rejected.

## Evidence: Passed and Failed Policy Runs
**Passed Run - Fully Compliant:**
The first run was made with the fully compliant stack to show the policies passing. The plan ran in HCP Terraform and showed 15 resources to add, and all five Sentinel policies PASSED, meaning the run was allowed to continue to apply. The screenshot is in documentation/screenshots/passed, the mocks downloaded from the run are in sentinel/mocks/Passed Run - Compliant and the plan output was saved to terraform/tfplan.

**Failed Policy Run - Data Residency:**
To demonstrate the policies blocking a non-compliant deployment, I deliberately broke four rules in a single commit. The DataResidency tag in providers.tf was changed from "IE" to "US", the "data" EBS volume was set to encrypted = false, http_tokens was set to "optional" and the admin_ssh_cidr was set to "0.0.0.0/0" which allows SSH from the whole internet. The region itself could not be changed to test this, as the validation in variables.tf stops the plan before Sentinel ever runs.

The plan ran in HCP and the sovereignty policy FAILED as hard-mandatory, meaning the run was blocked and could not be applied. The encryption, metadata and network policies also failed, but as these are set to "advisory" on the HCP free plan, they only show as warnings. instance_type passed as it was not changed. Screenshots are in documentation/screenshots, the full log is in sentinel/logs and the mocks are in sentinel/mocks/Failed Policy Check - Data Residency. The four changes were reverted in the following commit to return the stack to a compliant state.

One thing I noticed is that the sovereignty policy flagged 11 resources, including route tables and the internet gateway, as "holding sensitive data". This is because the DataClassification tag is applied to every resource through default_tags. In a real environment only resources that actually store data should be tagged as sensitive.

## Decision Justification
### Effectiveness of Policy as Code for digital sovereignty
The effectiveness of Policy as Code is that the policies and rules can be enforced and overseen centrally. Rather than relying on every developer writing compliant Terraform, the Sentinel policies sit outside of the Terraform code and are checked against every plan, as shown in the failed run where the "US" DataResidency tag blocked the deployment before anything was created. Policy as Code allows for the deliberate implementation of baseline restrictions, such as approved regions, encryption and IMDSv2. However, it is only one piece of the overall data security and sovereignty discussion. Compromised employees, data being intercepted in transit if it is not encrypted, and social engineering are all data sovereignty risks that Sentinel cannot see, and these have to be managed in other ways.

### Limitations of region-based data residency controls
Data residency does not automatically guarantee data sovereignty, as data may still be accessed or controlled by non-EU entities or subject to foreign legislation. Organisations must therefore consider additional factors, including encryption, access permissions, data processing locations and the legal jurisdiction of cloud providers.

### The importance of supply chain integrity
It is important that each and every point of a sensitive piece of data's journey is accounted for and managed. Data security is only as strong as the most vulnerable point in the chain, and if data is sent through a potentially insecure location then the data can be compromised. The same applies to the infrastructure code itself: the Terraform providers and modules are also links in the chain, as they run with access to the cloud account. If an untrusted provider or an unpinned version is pulled in, the infrastructure that holds the sensitive data could be compromised before it is even deployed, which is why the provider source, version and lock file checksums are controlled in this project.

### Limitations of Sentinel and Terraform plan-time enforcement
Sentinel only checks the Terraform plan, so it can only judge values that are known before anything is deployed. Values that are "known after apply", such as IDs and IP addresses, cannot be checked, so the policies treat missing or unknown values as a failure. Changes made outside of Terraform, for example someone opening SSH in the AWS console, are never seen by Sentinel at all. During testing the region itself could not be tested in HCP, as the validation in variables.tf stopped the plan before Sentinel ran.

### Challenges of maintaining policies as cloud environments evolve
Cloud environments constantly evolve, with providers introducing new services, regions, features and configuration options. Policies that were previously effective may become outdated or fail to account for new services, potentially creating compliance gaps. Organisations must regularly review, test and update their Sentinel policies to ensure they remain aligned with changing cloud infrastructure and EU regulatory requirements.

## AI Use Declaration
**Tool used:** Anthropic Claude, model Claude Opus 5.5 (claude-opus-5-5), used through the Claude Code extension in VS Code.

**What Claude was used for:**
- Generating the baseline Terraform stack, with comments explaining what each relevant line does.
- Writing the five Sentinel policies and the sentinel.hcl file, commented to explain the rules.
- Explaining concepts I was unsure of, such as IMDSv1 vs IMDSv2, EBS volumes, subnets, security groups, Sentinel mocks and the HCP Terraform setup.
- Splitting the network into the public, "app" and "data" subnets.
- Troubleshooting HCP Terraform issues, such as the missing credentials error and the free plan policy limits.
- Reorganising this README.md, fixing formatting and factual errors, and helping write some sections from my notes.

**What I did:**
I set up HCP Terraform and the GitHub repository, ran the Terraform plans and added the policies to HCP. I decided on and ran the failed policy run, choosing which rules to break, and captured the screenshots, mocks and logs as evidence. I made the design decisions, such as using a 3-tier network, keeping sovereignty as the hard-mandatory policy, and removing the supply chain Sentinel policy to keep the project simple and understandable. I reviewed and checked the code and explanations Claude provided, and wrote the analysis in this README from my own understanding.

**Example prompts used:**
- "Since this is a learning assignment, I'd like to start off with a skeleton, or basic terraform starting point. Can you generate this and comment the code that explains what relevant lines are doing?"
- "Let's write the sentinel policies. Comment the sentinel files simply to explain the relevant info."
- "Ill need private subnets for the sensitive data, like for the EBS volume. Can you separate the services out into private subnets for separation of concerns?"
- "Is the supply chain section a requirement? ... I feel this has added complication and muddles my understanding of it a bit."
- "Reorganise it first, I'll check the edits, then help me flesh out the readme."

All prompts are recorded in full in documentation/LLM Propmpt Log.
