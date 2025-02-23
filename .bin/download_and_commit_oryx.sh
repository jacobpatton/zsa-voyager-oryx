#!/usr/bin/env bash

PWD=$(pwd)

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

cd $SCRIPT_DIR/..

git checkout -b oryx

hashId=$(jq -r .'layout' $SCRIPT_DIR/../config.json)

geometry=$(jq -r .'geometry' $SCRIPT_DIR/../config.json)

response=$(curl --location 'https://oryx.zsa.io/graphql' --header 'Content-Type: application/json' --data '{"query":"query getLayout($hashId: String!, $revisionId: String!, $geometry: String) {layout(hashId: $hashId, geometry: $geometry, revisionId: $revisionId) {  revision { hashId, qmkVersion, title }}}","variables":{"hashId":"$hashId","geometry":"$geometry","revisionId":"latest"}}' | jq '.data.layout.revision | [.hashId, .qmkVersion, .title]')

hash_id=$(echo "${response}" | jq -r '.[0]')
firmware_version=$(printf "%.0f" $(echo "${response}" | jq -r '.[1]'))
change_description=$(echo "${response}" | jq -r '.[2]')

userspace_dir="oryx".$(echo hashId | tr '[:upper:]' '[:lower:]')

if [[ -z "${change_description}" ]]; then
   change_description="latest layout modification made with Oryx"
fi

curl -L "https://oryx.zsa.io/source/${hash_id}" -o $SCRIPT_DIR/../source.zip

unzip -oj $SCRIPT_DIR/../source.zip '*_source/*' -d $SCRIPT_DIR/../userspace/layouts/$userspace_dir

rm $SCRIPT_DIR/../source.zip

cd $SCRIPT_DIR/../userspace/layouts/$userspace_dir

git add .

git commit -m "✨(oryx): ${change_description}" || echo "No layout change"

git push

cd $SCRIPT_DIR/..

git fetch origin main

git checkout -B main origin/main
git merge -Xignore-all-space oryx
git push


git submodule update --init --remote --depth=1
cd qmk_firmware
git checkout -B firmware$firmware_version origin/firmware$firmware_version
git submodule update --init --recursive
cd ..
git add qmk_firmware
git commit -m "✨(qmk): Update firmware" || echo "No QMK change"
git push


if [ "$firmware_version" -ge 24 ]; then
   keyboard_directory="qmk_firmware/keyboards/zsa"
   make_prefix="zsa/"
else
   keyboard_directory="qmk_firmware/keyboards"
   make_prefix=""
fi

cd $PWD