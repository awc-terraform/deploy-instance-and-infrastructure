provider "aws" {
  region = var.aws_region
  profile = var.aws_profile
}

#----KMS----

resource "aws_kms_key" "instancesKMSkey" {
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
    Owner = vr.aws_owner
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
  instance = aws_instance.instance.id
  vpc      = true

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.instance.id
  allocation_id = aws_eip.eip.id

  depends_on = [aws_instance.instance, aws_eip.eip]

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}


#----EC2----

resource "aws_key_pair" "instanceskey" {
  key_name   = var.aws_key_pair
  public_key = file("instanceskey.pub")

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
  associate_public_ip_address = true

  tags = {
    Name        = "instance-${count.index}"
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }

  key_name = aws_key_pair.instancekey.key_name

  depends_on = [aws_key_pair.instanceskey, aws_kms_key.instancesKMSkey]

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
    kms_key_id            = aws_kms_key.instancesKMSkey.id
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
    cidr_blocks = "x.x.x.x/32"
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

resource "aws_network_interface_sg_attachment" "sg_attachment" {
  count = var.aws_count

  security_group_id    = element(aws_security_group.instances_sg.*.id, count.index)
  network_interface_id = element(aws_instance.instance.*.primary_network_interface_id, count.index)

  tags = {
    Name        = var.aws_name
    Owner       = var.aws_owner
    Dept        = var.aws_dept
    Tool        = var.aws_tool
  }
}




