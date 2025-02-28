# Better Bash
## screenshot:
![alt text](https://git.cz0.cz/czoczo/BetterBash/raw/branch/master/screenshot.png "BetterBash screenshot")
## Features
- Username (highlighted if root) and hostname.
- Unique avatar based on hostname (a bit like automatic avatars on StackOverflow), reduces the risk of terminal confusion.
- Number of background processes.
- Line separating commands output.
- Exit code if other than zero.
- Date and time.
- Current directory.
- Git status (if current directory inside git repository)
## Quick install:
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
curl https://cz0.cz/getbb | sh && . ~/.bashrc
```
