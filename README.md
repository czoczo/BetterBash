# Better Bash
Description? Pictures say more than words! 
## screenshot:
![alt text](https://cz0.cz/static/untracked/images/bb_example.png "Example of BetterBash at work")
## quick install:
```
URL='https://git.cz0.cz/czoczo/BetterBash/raw/branch/master/.bshell' && \
DIR=~/.bshell && \
CMD='[ -f ~/.bshell/bb.sh ] && . ~/.bshell/bb.sh' && \
mkdir -p $DIR && \
wget $URL/bb.sh -O $DIR/bb.sh && \
wget $URL/git-prompt.sh -O $DIR/git-prompt.sh && \
grep -q "$CMD" ~/.bashrc || echo "$CMD" >> ~/.bashrc && \
source ~/.bashrc
```
or just:
```
curl https://git.cz0.cz/getbb | sh && source ~/.bashrc
```
