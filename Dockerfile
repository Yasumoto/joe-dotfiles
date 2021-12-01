FROM ubuntu:21.10

ENV DEBIAN_FRONTEND noninteractive

RUN apt update && apt upgrade && apt install -y vim fish build-essential git sudo
