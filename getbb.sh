URL='https://git.cz0.cz/czoczo/BetterBash/raw/branch/master/.bshell' && \
DIR=~/.bshell && \
CMD='[ -f ~/.bshell/bb.sh ] && . ~/.bshell/bb.sh' && \
mkdir -p $DIR && \
wget $URL/bb.sh -O $DIR/bb.sh && \
wget $URL/git-prompt.sh -O $DIR/git-prompt.sh && \
grep -q "$CMD" ~/.bashrc || echo "$CMD" >> ~/.bashrc

