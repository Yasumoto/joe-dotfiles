#cloud-config

hostname: ${hostname}
package_update: true
package_upgrade: true
package_reboot_if_required: true

apt:
  sources:
    docker.list:
      source: deb [arch=amd64] https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

users:
  - default
  - name: joe
    gecos: joe
    shell: /usr/bin/fish
    primary_group: joe
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups:
      - users
      - admin
      - docker
    lock_passwd: true
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIPX7JYXqE77kBDsSB+gxRA+7ittu9gsAYtBw3CzoxBU yasumoto7+desktop@gmail.com
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqPRVBJLSnRoQh8Y3aQRGmCfxH2sTbccR4tmyN//3Jw yasumoto7+meerkat@gmail.com
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCTP0jj+eHsG7ov3sjRK78vcnZ6r1cFosRg2dOM0jcbsBV4kKocaBIS8i+ICv0CZB0qJdJ0V5MjCk6w8Cc5uqn2ipDCrNEO3QVBN9cOcosHHYrLLBVYS0UfOG4LHpftFzmRMSNN8xiOCqZaJwuxct6VYsX135RSQ2FAA62OPDv1KDXyqd9KU/+j4vP8yzmLa8tuIGuB4Ce4biEOfNFZZvpFTOX/6wIJL6ZGsoVoNvyZgATwHsCOgkxfLfxNgK2NIg9OfSga+/cUX42ReFyq4ZVz6x990FJzHHmFYAWyyb/XnHXo3SH/7Nq0B91oimlorNVKamPUXsF3wkbPIhih0uI4xLfHb1inPCOly2P090uPmA1hJwVRqQnpbluWxyOKRjw+igKCGDwW051MvYC0PNmZIEjlfoACqMu9AQeIUJfdHcKxiq9DB3ikvUMU7bioM4gnjuHljZcqzt030nRRab5VMk9XVgi/O4e1ji7X+tBsDqRhGKKgyzXMmX2E4r3fph0Er/PoQXnUrt/XBdlfMBoF3UrvIFziiVGIrqid3LsMxmGEd3b+cuu3Ah1ScVMjrg95P8dsdZxWb3gqlW6dqF+lMXkG+UZU+ffKxdraadTguCXCbQVwcSXCEegcwiUsozuqFGpgROMa5tDEvwSVpIS0YqjCfIs6R010QU7dtczusQ== yasumoto7+stormtrooper@gmail.com
      - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN5+arDLfB5cHiyUrVaEerDmd7Mt1SUrBSwsNrq7wv90 yasumoto7+joe-lemur@gmail.com


packages:
  - fish
  - mosh
  - docker-ce
  - docker-ce-cli

