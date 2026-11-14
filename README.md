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
I have the Terraform files set up. The main.tf file establishes an instance type of t3.micro to host the application called "web". The aws_instance contains a root_block_device to store the data required for hosting and configuirting the AWS Web Instance. Seperately there is an Elastic Bean Stalk valoume, named "data", that will contain the possibly sensitive data. In the "data" ebs volume, the encryption tag is set to "true". This ensures that the data stored on the aws_ebs_volume is seperate from where the EC2 web OS and configuration is stored. The enyption will be specified using "encryption.sentinel".

Subnets:
Currently there is no internet gateway attached to the VPC, meaning that the whole VPC is still private. There exists only one subnet "main" currently. If the application needed to be fully publically accessible, it would be a good idea to create several subnets, keeping only the "web" EC2 service on the public subnet while keeping other setvices, like the EBS volume on a private subnet.