# Grupo de seguridad perimetral para la isntancia
resource "aws_security_group" "web_sg" {
  name        = "cloud1-web-sg-${var.environment}"
  description = "Firewall rules for Inception: SSH(22) and HTTP(80) y HTTPS(443)"
  vpc_id      = aws_vpc.main.id

  #1 Acceso SSH (PAra Ansible y administracion remota)
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #2 Acceso Web HTTP (Nginx / Certifiados / Redirección)
  ingress {
    description = "Trafico web HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #3. Acceso Web Seguro HTPPS (Wordpress via Nginx SSL)
  ingress {
    description = "Trafico web seguro HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #4. Egreso ilimitado a Internet (Apt, Docker Hub, actualizaciones)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud1-web-sg-${var.environment}"
  }
}
