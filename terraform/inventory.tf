resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    lb   = docker_container.lb.name
    app1 = docker_container.app1.name
    app2 = docker_container.app2.name
  })
  filename = "${path.module}/../ansible/inventory/hosts.ini"
}