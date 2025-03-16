#!/bin/bash
sed -i '/BetterBash/,+1d' ~/.bashrc && \
sed -i '/BetterBash/,+4d' ~/.inputrc && \
rm -r ~/.bb

