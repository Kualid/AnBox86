#!/bin/bash

set -e # exits if there's some commands has non-zero status

apt update

apt install git cmake python3 build-essential gcc

git clone https://github.com/ptitSeb/box86

sh -c "cd box86 && cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo ~/box86 && make && make install"

wget https://twisteros.com/wine.tgz

tar -xvzf wine.tgz

apt install xserver-xephyr

echo >> launch.sh "export DISPLAY=localhost:0

Xephyr :1 -fullscreen

DISPLAY=:1 box86 ~/wine/bin/wine explorer /desktop=wine,1280x720 explorer"


echo "installation complete, you can use launch.sh to start box86 and wine, make sure you have the  xserverxsdl app running "
