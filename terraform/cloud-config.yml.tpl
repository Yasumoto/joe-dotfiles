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

packages:
  - fish
  - mosh
  - docker-ce
  - docker-ce-cli

