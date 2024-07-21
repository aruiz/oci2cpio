#!/usr/bin/fakeroot bash

TEST_CONTAINER=quay.io/fedora/fedora-bootc
DESTDIR=`mktemp -d`

./oci2cpio.sh quay.io/fedora/fedora-bootc $DESTDIR

if [ ! -f $DESTDIR/initramfs.cpio ] ; then
    rm -rf $DESTDIR
    echo "bundled cpio file did not exist"
    exit 1
fi

mkdir $DESTDIR/tars
mkdir $DESTDIR/cpios

for i in `jq '.layers[] | select(.mediaType == "application/vnd.oci.image.layer.v1.tar+gzip") | .digest' $DESTDIR/manifest.json | sed -s s/\"sha256\:// | sed -s s/\"$//`; do
   tar xvf $DESTDIR/$i -C $DESTDIR/tars > /dev/null
   cat $DESTDIR/[0-9][0-9].$i.cpio | cpio -idcmv -D $DESTDIR/cpios 
done

ls -lah $DESTDIR/tars
ls -lah $DESTDIR/cpios

#TODO: compare trees
#rm -rf $DESTDIR    ª