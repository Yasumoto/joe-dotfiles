#!/bin/sh

PASSWORD="$1"

export DEBIAN_FRONTEND=noninteractive


# taken care of in the docker file
#apt update
# apt-get -y install maas

#apt reinstall maas-region-controller
#apt reinstall maas-rack-controller

# Complains about lacking systemd
# maas-rack register

maas createadmin --username joe --password "$PASSWORD" --email yasumoto7@gmail.com --ssh-import gh:Yasumoto

# Wait on the region controller instead?
sleep 600
