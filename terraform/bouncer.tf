data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-hirsute-21.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_ebs_volume" "bouncer" {
  availability_zone = aws_instance.bouncer.availability_zone
  size              = 40
  type              = "gp3"

  tags = {
    terraform = "true"
    Name = "bouncer"
  }
}

resource "aws_volume_attachment" "ebs_bouncer" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.bouncer.id
  instance_id = aws_instance.bouncer.id
}

resource "aws_instance" "bouncer" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.allow_ssh.id, aws_security_group.allow_mosh.id]
  subnet_id       = aws_subnet.main.id
  user_data       = templatefile("${path.module}/cloud-config.yml.tpl", { hostname = "bouncer" })

  tags = {
    terraform = "true"
    Name      = "bouncer"
  }
}
