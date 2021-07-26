FROM ubuntu:20.04

ARG MAAS_PASSWORD

ENV DEBIAN_FRONTEND noninteractive

EXPOSE 5240

RUN find /etc/systemd/system \
         /lib/systemd/system \
         -path '*.wants/*' \
         -not -name '*journald*' \
         -not -name '*systemd-tmpfiles*' \
         -not -name '*systemd-user-sessions*' \
         -exec rm \{} \;
RUN systemctl set-default multi-user.target

RUN apt update && apt-get -y upgrade && \
    apt-get -y install sudo software-properties-common jq && \
    apt-add-repository ppa:maas/3.0
    #DEBIAN_FRONTEND=noninteractive apt-get -y install maas && \
    #apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get install -y systemd

RUN apt-get install -y rsyslog
RUN systemctl enable rsyslog.service

COPY ./startup.sh /

CMD /startup.sh $MAAS_PASSWORD
