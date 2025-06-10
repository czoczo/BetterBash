#!/bin/bash
sed -i '/BetterBash/,+2d' ~/.bashrc && \
sed -i '/BetterBash/,+4d' ~/.inputrc && \
rm -r ~/.bb && \
echo "BetterBash uninstallation completed. Restart your bash session to see the effect."

