#!/bin/bash

get_file() {
  HOST="git.cz0.cz"
  echo -e "GET /czoczo/BetterBash/raw/branch/master/$1 HTTP/1.1\r\nHost: $HOST\r\nConnection: close\r\n\r\n" \
  | openssl s_client -quiet -connect $HOST:443 2>/dev/null \
  | sed '1,/^\r$/d'
}

DIR=~/.bb
CMD=$(cat <<-END
# BetterBash
[ -f $DIR/bb.sh ] && . $DIR/bb.sh
END
)

mkdir -p $DIR && \
get_file /prompt/bb.sh > $DIR/bb.sh && \
get_file /prompt/git-prompt.sh > $DIR/git-prompt.sh && \
grep -q "BetterBash" ~/.inputrc || get_file /.inputrc >> ~/.inputrc && \
bind -f ~/.inputrc && \
grep -q "BetterBash" ~/.bashrc || echo "$CMD" >> ~/.bashrc
