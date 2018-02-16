#!/bin/bash
cd /data/tmp/
git clone http://127.0.0.1:3000/czoczo/BetterBash
cp /data/tmp/BetterBash/getbb.sh /wwwroot/getbb.sh
tar -czvf betterbash-latest.tar.gz -C /data/tmp/BetterBash/ . --exclude=".git" --exclude="README.md --exclude="getbb.sh""
rm -rf /data/tmp/BetterShell
rm /wwwroot/betterbash-latest.tar.gz
mv betterbash-latest.tar.gz  /wwwroot/betterbash-latest.tar.gz
