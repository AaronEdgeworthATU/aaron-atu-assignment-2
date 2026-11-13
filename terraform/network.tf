# -----------------------------------------------------------------------------
# network.tf
# A minimal private network: one VPC, one subnet, one security group.
# The security group is what the "no unrestricted SSH" policy will inspect.
# -----------------------------------------------------------------------------

# A VPC is your own isolated network inside AWS.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # lets instances resolve DNS names
  enable_dns_hostnames = true # gives instances internal DNS hostnames

  tags = {
    Name = "${var.organisation}-vpc" # e.g. "ATUL0012345-vpc"
  }
}

# A subnet is a slice of the VPC's IP range, placed in ONE availability zone.
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id # reference: "the id of the VPC above"
  cidr_block = var.subnet_cidr

  # Pin the AZ to a zone inside the approved region (eu-west-1a = Dublin).
  availability_zone = "${var.aws_region}a"

  # false = instances do NOT automatically get a public IP. Keeping servers
  # off the public internet by default is good network security.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.organisation}-subnet"
  }
}

# A security group is a stateful firewall attached to instances.
resource "aws_security_group" "web" {
  name        = "${var.organisation}-web-sg"
  description = "Allow HTTPS from anywhere, SSH only from the admin network"
  vpc_id      = aws_vpc.main.id

  # Inbound rule 1: HTTPS (443) open to the world is normal for a web server.
  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule 2: SSH (22) restricted to the admin range ONLY.
  # The compliant pattern: a Sentinel policy will reject any plan where port 22
  # is open to 0.0.0.0/0.
  ingress {
    description = "SSH from admin network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }

  # Outbound: allow all. protocol "-1" means "all protocols".
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.organisation}-web-sg"
  }
}
