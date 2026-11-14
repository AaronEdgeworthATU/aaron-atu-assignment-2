# -----------------------------------------------------------------------------
# main.tf
# The compute and storage resources. Each security-relevant setting below maps
# to one of the assignment's Sentinel policies (named in the comments).
# -----------------------------------------------------------------------------

resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type # -> instance_type.sentinel (approved sizes)

  subnet_id              = aws_subnet.app.id           # private app tier (network.tf)
  vpc_security_group_ids = [aws_security_group.web.id] # -> network.sentinel

  # Instance Metadata Service (IMDS) settings -> metadata.sentinel
  # IMDSv2 requires a session token before the metadata service answers,
  # which protects the instance's AWS credentials from SSRF attacks.
  metadata_options {
    http_endpoint               = "enabled"  # metadata service is on...
    http_tokens                 = "required" # ...but ONLY via IMDSv2 tokens
    http_put_response_hop_limit = 1          # token can't travel past the instance (e.g. into containers)
  }

  # The instance's boot disk -> encryption.sentinel
  root_block_device {
    encrypted   = true  # encrypt data at rest
    volume_type = "gp3" # current-generation general-purpose SSD
    volume_size = 8     # GiB
  }

  tags = {
    Name = "${var.organisation}-web"
  }
}

# A separate data disk, e.g. for application data. Because it would hold
# "sensitive" data, it must be encrypted AND stay in the approved region.
resource "aws_ebs_volume" "data" {
  # Same AZ as the instance (a volume can only attach within one AZ).
  # The disk has to be in the same AZ as the instance it attaches to.
  availability_zone = aws_subnet.app.availability_zone
  size              = 10
  type              = "gp3"
  encrypted         = true # -> encryption.sentinel

  # Optional: a customer-managed KMS key gives you control over who can decrypt.
  # Left out here to keep the skeleton simple (AWS-managed key is used).
  # kms_key_id = aws_kms_key.data.arn

  tags = {
    Name = "${var.organisation}-data"
  }
}

# Attach the data disk to the instance as /dev/sdf.
resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web.id
}
