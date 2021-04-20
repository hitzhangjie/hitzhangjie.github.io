#!/bin/bash

publishDir=hitzhangjie.github.io

rm $publishDir/index.min.*js
rm $publishDir/main.*.css
rm $publishDir/main.min.*.js

npm run build

cd $publishDir
git pull
msg="$(date +'%F %T') rebuild site"
git add .
git cc -m "$msg"
git push
