#!/bin/bash

printHelp() {
    printf '%s' "$(cat <<EOF
Usage: $0 [download method]

Available methods:
  curl
  wget
  openssl
 
EOF
)"
    exit 0
}


case $1 in
    curl|wget|openssl) true ;;
    *) printHelp ;;
esac


HOST="git.cz0.cz"
ENDPOINT="/czoczo/BetterBash/raw/branch/master"

get_file_openssl() {
  echo -e "GET $ENDPOINT/$1 HTTP/1.1\r\nHost: $HOST\r\nConnection: close\r\n\r\n" \
  | openssl s_client -quiet -connect $HOST:443 2>/dev/null \
  | sed '1,/^\r$/d' \
  | sed -E ':a;N;$!ba;s/(\r\n)?[a-f0-9]+\r\n//g' \
  | sed 's/\r$//'
}

get_file_curl() {
  curl -sL "https://${HOST}${ENDPOINT}/$1"
}

get_file_wget() {
  wget -q -O - "https://${HOST}${ENDPOINT}/$1"
}

get_file() {
  case $1 in
  "curl")
    get_file_curl "$2"
    ;;
  "wget")
    get_file_wget "$2"
    ;;
  "openssl")
    get_file_openssl "$2"
    ;;
  esac
}

handle_inputrc() {
  [ ! -f ~/.inputrc ] && touch ~/.inputrc
  grep -q "BetterBash" ~/.inputrc || get_file "$1" /.inputrc >> ~/.inputrc
}

DIR=~/.bb
CMD=$(cat <<-END
# BetterBash
[ -f $DIR/bb.sh ] && . $DIR/bb.sh
bind -f ~/.inputrc
END
)

mkdir -p $DIR && \
get_file "$1" /prompt/bb.sh > $DIR/bb.sh && \
get_file "$1" /prompt/git-prompt.sh > $DIR/git-prompt.sh && \
handle_inputrc "$1" && \
grep -q "BetterBash" ~/.bashrc || echo "$CMD" >> ~/.bashrc
