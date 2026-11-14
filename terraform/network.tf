# -----------------------------------------------------------------------------
# network.tf
# A three-tier network, so each kind of resource only gets the access it needs:
#
#   VPC 10.0.0.0/16 (eu-west-1)
#   ├── public  10.0.1.0/24  route to the internet gateway. Empty for now,
#   │                        reserved for a future load balancer.
#   ├── app     10.0.2.0/24  PRIVATE. The web server and its EBS data disk.
#   └── data    10.0.3.0/24  PRIVATE. Reserved for a future database; only
#                            reachable from the web server's security group.
#
# Only the public subnet has a route to the internet. Private subnets can only
# talk to other addresses inside the VPC.
# -----------------------------------------------------------------------------

# A VPC is your own isolated network inside AWS.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true # lets instances resolve DNS names
  enable_dns_hostnames = true # gives instances internal DNS hostnames

  tags = {
    Name = "${var.organisation}-vpc" # e.g. "L00205292-vpc"
  }
}

# -----------------------------------------------------------------------------
# Public tier
# -----------------------------------------------------------------------------

# The internet gateway is the VPC's door to the internet. Without one, nothing
# in the VPC can reach or be reached from the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.organisation}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr
  availability_zone = "${var.aws_region}a" # eu-west-1a = Dublin

  # Still false: anything public (e.g. a load balancer) should get its public
  # address deliberately, not automatically. network.sentinel enforces this.
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.organisation}-public"
    Tier = "public"
  }
}

# A route table is a set of "to reach X, send traffic to Y" rules.
# What makes a subnet "public" is ONLY this: a route to an internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # any address not inside the VPC...
    gateway_id = aws_internet_gateway.main.id # ...goes out via the internet gateway
  }

  tags = {
    Name = "${var.organisation}-public-rt"
  }
}

# Links the public route table to the public subnet.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Private tiers (app + data)
# -----------------------------------------------------------------------------

# The app subnet: holds the web server and, through it, the EBS data disk.
resource "aws_subnet" "app" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.app_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.organisation}-app"
    Tier = "private"
  }
}

# The data subnet: reserved for sensitive data services such as a database.
resource "aws_subnet" "data" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.data_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.organisation}-data"
    Tier = "private"
  }
}

# A private route table with NO internet route. It only has AWS's built-in
# "local" route (traffic within 10.0.0.0/16), so these subnets are isolated
# from the internet in both directions.
# (A NAT gateway would let private servers download updates outbound-only,
# but it costs money, so it's left out of this plan-only project.)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.organisation}-private-rt"
  }
}

resource "aws_route_table_association" "app" {
  subnet_id      = aws_subnet.app.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data" {
  subnet_id      = aws_subnet.data.id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# Security groups (stateful firewalls attached to resources)
# -----------------------------------------------------------------------------

# Firewall for the web server.
resource "aws_security_group" "web" {
  name        = "${var.organisation}-web-sg"
  description = "Allow HTTPS from anywhere, SSH only from the admin network"
  vpc_id      = aws_vpc.main.id

  # HTTPS (443). The server is private, so in practice this traffic would
  # arrive via a future load balancer in the public subnet.
  ingress {
    description = "HTTPS from the internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (22) restricted to the admin range ONLY. network.sentinel rejects
  # any plan where port 22 is open to 0.0.0.0/0.
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

# Firewall for the data tier. Instead of IP ranges, it allows traffic from
# another SECURITY GROUP: only resources wearing the web security group can
# connect. Nothing else, including the internet, can reach the data tier.
resource "aws_security_group" "data" {
  name        = "${var.organisation}-data-sg"
  description = "Database access from the web tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from web servers only"
    from_port       = 5432 # example database port (PostgreSQL)
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # No egress block = no outbound traffic allowed. A database only needs to
  # answer requests (replies are allowed automatically: SGs are stateful).

  tags = {
    Name = "${var.organisation}-data-sg"
  }
}
