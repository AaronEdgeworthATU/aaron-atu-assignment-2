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