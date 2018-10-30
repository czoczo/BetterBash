#!/bin/bash
wget cz0.cz/betterbash-latest.tar.gz -q -O - | tar -xz --no-same-owner -C ~
CMD='[ -f ~/.bshell/bb.sh ] && . ~/.bshell/bb.sh'
grep -q "$CMD" ~/.bashrc || echo "$CMD" >> ~/.bashrc
