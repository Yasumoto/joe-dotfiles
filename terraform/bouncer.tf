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

resource "aws_instance" "bouncer" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  associate_public_ip_address = true

  security_groups = [aws_security_group.allow_ssh.id, aws_security_group.allow_mosh.id]
  subnet_id       = aws_subnet.main.id
  user_data       = templatefile("${path.module}/cloud-config.yml.tpl", { hostname = "bouncer" })

  root_block_device {
    volume_type = "gp3"
  }

  tags = {
    terraform = "true"
    Name      = "bouncer"
  }
}
