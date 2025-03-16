#!/bin/bash
get_file() {
  echo -e "GET /czoczo/BetterBash/raw/branch/master/$1 HTTP/1.1\r\nHost: git.cz0.cz\r\nConnection: close\r\n\r\n" \
  | openssl s_client -quiet -connect cz0.cz:443 2>/dev/null \
  | sed '1,/^\r$/d'
}

DIR=~/.bb && \
CMD="[ -f $DIR/bb.sh ] && . $DIR/bb.sh" && \
mkdir -p $DIR && \
get_file /prompt/bb.sh > $DIR/bb.sh && \
get_file /prompt/git-prompt.sh > $DIR/git-prompt.sh && \
get_file /.inputrc >> ~/.bb/.inputrc && \
grep -q "$CMD" ~/.bashrc || echo "$CMD" >> ~/.bashrc
