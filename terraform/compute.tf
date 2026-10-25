# 1. Búsqueda dinámica de la AMI oficial más reciente de Ubuntu 22.04 LTS
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

#2. Registro de la clave pública SSH en AWS
resource "aws_key_pair" "deployer" {
  key_name   = "cloud1-key-${var.environment}"
  public_key = file(var.ssh_public_key_path)

  tags = {
    Name = "cloud1-key-${var.environment}"
  }
}

#3. Instancia EC2 (Apta para free tier)
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instace_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  # Almacenamiento raíz (Volumen EBS)
  root_block_device {
    volume_size           = 20 # 20 GB (capa gratuita de AWS hasta 30 Gb)
    volume_type           = "gp3"
    delete_on_termination = true

    tags = {
      Name = "cloud1-web-root-volume-${var.environment}"
    }
  }

  tags = {
    Name = "cloud1-web-${var.environment}"
  }
}