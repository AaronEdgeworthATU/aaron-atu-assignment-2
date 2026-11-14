# aaron-atu-assignment-2
Terraform Digital Sovereignty Assignment - Ruth Lennon

I've began with generating a base terraform system or template stack to work from. 
This does not have many security considerations or any Sentinel policies implmented yet. 
This is to establish a base project that will successfully run 'terraform init'.
Anthropic's Claude was used to generate the baseline files. 

In main.tf the providers tag establishes the baseline AWS Services. An EC2 t3.micro 
service for web hosting. Importantly it alters some of the metadata_options requiring IMDSv2 tokens, 
requiring connections to possess an assigned connection token first.

Versioning issues when running 'terraform plan'. Alterations made to the version to allow any 1.17.x 
version.

Terraform Base Stack/Skeleton:
I have the Terraform files set up. The main.tf file establishes an instance type of t3.micro to host the application called "web". The aws_instance contains a root_block_device to store the data required for hosting and configuirting the AWS Web Instance. Seperately there is an Elastic Book Store valoume, named "data", that will contain the possibly sensitive data. In the "data" ebs volume, the encryption tag is set to "true". This ensures that the data stored on the aws_ebs_volume is seperate from where the EC2 web OS and configuration is stored. The enyption will be specified using "encryption.sentinel".

Subnets:
Currently there is no internet gateway attached to the VPC, meaning that the whole VPC is still private. There exists only one subnet "main" currently. If the application needed to be fully publically accessible, it would be a good idea to create several subnets, keeping only the "web" EC2 service on the public subnet while keeping other setvices, like the EBS volume on a private subnet.

Further changes to the network.tf file was made. Previous there was just one main subnet that had no Internet Gateway, so the whole subnet was private and inaccessible. It is now serperated into a public subnet and 2 private subnets ("app" and "data"). The stack is based on a 3-tier architecture, similar to the previous assignment to keep things familiar. The inclusion of further subnets can enhance security, invokes seperation of concerns and prevents there being a single point of failure/compromise. 
A routing table was added with an internet gateway, allowing for public internet connections to be directed towards the public subnet hosting the web layer.

A security group was also added which ensures that only PostgreSQL resources in the web security group is permitted and forbids outbound traffic for anything contained in this web security group.

Sentinel Policies:
Five sentinel policies have been defined will ensure a failed run if any of the rules defined are breached. The sentinel.hcl file enforces "hard_mandatory" rules on 4 of the policies, meaning that if anything in the stack is in breach of the deployment rules HCP Sentinel will FAIL the stack plan/apply. 
    - sovereignty.sentinel: The rules in this policy ensure that the region that the resources are created in ONLY exist in approved_regions = "eu-west-1". The tages "sensitive" and "confidential" are created and a check is done to check the Data Classification and Data Residency. If the serives are not in "IE" then the policy will fail, as the data is not under Irish jurisdiction.
    - encryption.sentinel: The rules in this policy ensure that ALL EBS storage is encrypted at rest. There are three places a disk can be defined in Terraform, so all three are checked: the root_block_device on the aws_instance, any extra ebs_block_device on the instance, and the separate aws_ebs_volume "data". Each one must have encrypted = "true". If the root_block_device is missing completely the policy will also fail, as the AMI default could be unencrypted.
    - metadata.sentinel: The rules in this policy ensure that every aws_instance requires IMDSv2 tokens, with http_tokens = "required" in the metadata_options block. If http_tokens is set to "optional", or the metadata_options block is missing, the policy will fail, as IMDSv1 would allow a plain GET request to retrieve the instance credentials (SSRF attack).
    - network.sentinel: The rules in this policy ensure that SSH (port 22) is NOT open to the whole internet ("0.0.0.0/0"). Only port 443 (HTTPS) is approved to be open to the internet, any other port open to the internet will fail. The subnet and instance are also checked so that they do not assign public IP addresses automatically (map_public_ip_on_launch and associate_public_ip_address). Inbound rules can be written three different ways in Terraform, so all three are checked so the policy can't be avoided.
    - instance_type.sentinel: The rules in this policy ensure that the aws_instance ONLY uses an approved instance type, approved_instance_types = "t3.micro", "t3.small" or "t3.medium". This is the one policy set to "soft-mandatory" in sentinel.hcl, as it is more of a cost decision than a security one, meaning an organisation owner can override a failure if a larger instance is needed.