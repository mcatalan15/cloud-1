# 1. Salidas por pantalla en la terminal tras el despliegue
output "instance_public_ip" {
  description = "Dirección IP pública de la instancia EC2"
  value       = aws_instance.web.public_ip
}

output "instance_id" {
  description = "ID único de la instancia EC2 en AWS"
  value       = aws_instance.web.id
}

output "ssh_connection_command" {
  description = "Comando rápido para verificar la conexion SSH"
  value       = "ssh -i ${var.ssh_public_key_path} ubuntu@${aws_instance.web.public_ip}"
}

# 2. Generacion automatica del inventario de Ansible
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/hosts.tpl", {
    server_ip = aws_instance.web.public_ip
  })
  filename = "${path.module}/../ansible/inventory/hosts.yml"

  # Permisos de lectura/escritura estandard para el archivo generado
  file_permission = "0644"
}