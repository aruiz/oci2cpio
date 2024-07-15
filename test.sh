#!/bin/bash

TEST_CONTAINER=quay.io/fedora/fedora-bootc
TEMP=`mktemp -d`

./oci2cpio.sh quay.io/fedora/fedora-bootc $TEMP

if [ ! -f $TEMP/initramfs.cpio ] ; then
    rm -rf $TEMP
    echo "bundled cpio file did not exist"
    exit 1
fi

mkdir $TEMP/tars
mkdir $TEMP/cpios

for i in `jq '.layers[] | select(.mediaType == "application/vnd.oci.image.layer.v1.tar+gzip") | .digest' $DESTDIR/manifest.json | sed -s s/\"sha256\:// | sed -s s/\"$//`; do
   tar 
done

rm -rf $TEMP