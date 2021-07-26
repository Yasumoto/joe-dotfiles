FROM ubuntu:20.04

RUN apt update && apt-get -y upgrade && \
    apt-get -y install software-properties-common && \
    apt-add-repository ppa:maas/3.0 && \
    apt-get -y install maas && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

