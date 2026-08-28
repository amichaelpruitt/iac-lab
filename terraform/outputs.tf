output "network_name" {
  value = docker_network.lab.name
}

output "container_names" {
  value = {
    lb   = docker_container.lb.name
    app1 = docker_container.app1.name
    app2 = docker_container.app2.name
  }
}


