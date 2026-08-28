resource "docker_network" "lab" {
  name = "iac-lab"
}

resource "docker_image" "debian" {
  name = "debian:bookworm-slim"
}

resource "docker_container" "lb" {
  name    = "lb"
  image   = docker_image.debian.image_id
  command = ["sleep", "infinity"]

  networks_advanced {
    name = docker_network.lab.name
  }
}

resource "docker_container" "app1" {
  name    = "app1"
  image   = docker_image.debian.image_id
  command = ["sleep", "infinity"]

  networks_advanced {
    name = docker_network.lab.name
  }
}

resource "docker_container" "app2" {
  name    = "app2"
  image   = docker_image.debian.image_id
  command = ["sleep", "infinity"]

  networks_advanced {
    name = docker_network.lab.name
  }
}