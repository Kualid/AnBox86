#!/bin/bash

set -e # exits if there's some commands has non-zero status

apt update

pkg update

pkg install proot-distro

linux32 proot-distro install ubuntu-20.04

apt install git

git clone https://github.com/ZhymabekRoman/proot-static

export PATH=$HOME/proot-static/bin:$PATH

export PROOT_LOADER=$HOME/proot-static/bin/loader

echo >> launch.sh "export PATH=$HOME/proot-static/bin:$PATH

export PROOT_LOADER=$HOME/proot-static/bin/loader

proot-distro login ubuntu-20.04"

echo -e "proot installation complete, you can start the proot by using launch.sh, please complete the installation  by bashing AnBox86b.sh to install box86 and wine on the proot"

proot-distro login ubuntu-20.04

