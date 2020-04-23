provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

#----KMS----

resource "aws_kms_key" "instanceKMSkey" {
  description = "KMS key to be used for encrypting ebs block devices on instances"
  is_enabled  = true

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

#----VPC----

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name  = var.aws_name
    Owner = var.aws_owner
    Dept  = var.aws_dept
    Tool  = var.aws_tool
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

resource "aws_eip" "eip" {
  count         = var.aws_count
  instance = element(aws_instance.instance.*.id, count.index)
  vpc      = true

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

resource "aws_eip_association" "eip_assoc" {
  count         = var.aws_count
  instance_id   = element(aws_instance.instance.*.id, count.index)
  allocation_id = element(aws_eip.eip.*.id, count.index)

  depends_on = [aws_instance.instance, aws_eip.eip]
}


#----EC2----

resource "aws_key_pair" "instancekey" {
  key_name   = var.aws_key_pair
  public_key = file(var.aws_public_key)

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

resource "aws_instance" "instance" {
  count         = var.aws_count
  ami           = var.aws_ami # us-east-1 
  instance_type = var.aws_instances_type
  subnet_id     = aws_subnet.main.id

  tags = {
    Name        = "instance-${count.index}"
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }

  key_name = aws_key_pair

  depends_on = [aws_key_pair.instancekey, aws_kms_key.instanceKMSkey]

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 125
    delete_on_termination = true
  }

  ebs_block_device {
    device_name           = "xvdf"
    volume_type           = "gp2"
    volume_size           = 50
    delete_on_termination = true
    encrypted             = true
    kms_key_id            = aws_kms_key.instanceKMSkey.id
  }
}

resource "aws_security_group" "instances_sg" {

  name        = "instances_sg"
  description = "Allows RDP into instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.aws_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

resource "aws_network_interface" "network_interface" {
  count = var.aws_count
  subnet_id       = aws_subnet.main.id
  security_groups = [aws_security_group.instances_sg.id]

  attachment {
    instance     = element(aws_instance.instance.*.id, count.index)
    device_index = 1
  }
}




