#!/bin/bash

get_file() {
  HOST="git.cz0.cz"
  echo -e "GET /czoczo/BetterBash/raw/branch/master/$1 HTTP/1.1\r\nHost: $HOST\r\nConnection: close\r\n\r\n" \
  | openssl s_client -quiet -connect $HOST:443 2>/dev/null \
  | sed '1,/^\r$/d' \
  | sed -E ':a;N;$!ba;s/(\r\n)?[a-f0-9]+\r\n//g' \
  | sed 's/\r$//'
}

handle_inputrc() {
  [ ! -f ~/.inputrc ] && touch ~/.inputrc
  grep -q "BetterBash" ~/.inputrc || get_file /.inputrc >> ~/.inputrc
}

DIR=~/.bb
CMD=$(cat <<-END
# BetterBash
[ -f $DIR/bb.sh ] && . $DIR/bb.sh
bind -f ~/.inputrc
END
)

mkdir -p $DIR && \
get_file /prompt/bb.sh > $DIR/bb.sh && \
get_file /prompt/git-prompt.sh > $DIR/git-prompt.sh && \
handle_inputrc && \
grep -q "BetterBash" ~/.bashrc || echo "$CMD" >> ~/.bashrc
