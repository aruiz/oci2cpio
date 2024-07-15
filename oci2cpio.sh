#!/bin/sh

# Author: Alberto Ruiz <aruiz@redhat.com>
# License: MIT
#
# This script downloads an OCI image from a remote repository and converts its layers
# with media type "application/vnd.oci.image.layer.v1.tar+gzip" to cpio archives.
#
# Usage: ./script_name.sh OCIREMOTE [DESTDIR]
#
# Arguments:
#   OCIREMOTE: The remote OCI repository from which to download the image.
#   DESTDIR: Optional. The directory where the image layers and cpio archives will be stored.
#            If not provided, a temporary directory will be created.
#
# The script performs the following steps:
# 1. Checks if the required arguments are provided and creates the destination directory if necessary.
# 2. Downloads the OCI image from the specified remote repository using 'skopeo'.
# 3. Extracts the layers with the specified media type from the manifest.json file.
# 4. Converts each layer to a cpio archive and stores it in the destination directory.


function usage () {
cat <<EOL
    Usage: ./script.sh OCIREMOTE [DESTDIR]

    Download an OCI (Open Container Initiative) image from a remote repository and convert the image layers into CPIO archives.

    Arguments:
    OCIREMOTE   The remote OCI image location in the format \`repository/image:tag\`.
                This argument is required.
    DESTDIR     The directory where the OCI image will be stored and processed.
                If not provided, a temporary directory will be created.

    Options:
    -h, --help  Show this help message and exit.

    Examples:
    Download an OCI image and use a temporary directory for the destination:
        ./script.sh myrepo/myimage:latest

    Download an OCI image and specify a destination directory:
        ./script.sh myrepo/myimage:latest /path/to/destination

    Notes:
    - Ensure you have \`skopeo\`, \`jq\`, and \`bsdtar\` installed.
    - The script creates CPIO archives from image layers and saves them in the specified \`DESTDIR\`.

    For more information, see the script’s [README.md](README.md).
EOL
}

REMOTE=$1
DESTDIR=$2

if [ -z "$REMOTE" ] ; then
    usage 1>&2
    exit 1
fi

if [ -z "${DESTDIR}" ] ; then
    if ! DESTDIR=`mktemp -d` ; then
        echo "Could not create tmpdir" 1>&2
        exit 1
    fi
else
    if ! test -d $DESTDIR ; then
        echo "{}" 1>&2
        exit 1
    fi
fi
echo "Creating cpio archive at ${DESTDIR}"
 
if ! skopeo copy docker://$REMOTE dir:$DESTDIR ; then
    echo "skopeo failed to download OCI image" 1>&2
    exit 1
fi

if ! test -f $DESTDIR/manifest.json ; then
    echo "missing manifest.json file in $DESTDIR"
    exit 1
fi

INITRAMFS=`mktemp`

index=0
for i in `jq '.layers[] | select(.mediaType == "application/vnd.oci.image.layer.v1.tar+gzip") | .digest' $DESTDIR/manifest.json | sed -s s/\"sha256\:// | sed -s s/\"$//`; do
    if ! test -f $DESTDIR/$i ; then
        echo "$DESTDIR/$i did not exist" 1>&2
        exit 1
    fi

    index_text=`printf "%02d" $index`
    TARGET="${DESTDIR}/${index_text}.${i}.cpio"
    if ! bsdtar --format=newc -cf - @$DESTDIR/$i > $TARGET  ; then
        echo "Could not convert $DESTDIR/$i to cpio"  1>&2
        rm -f $INITRAMFS
        exit 1
    fi

    if ! cat $TARGET >> $INITRAMFS ; then
        echo "Could not append archive to temporary file $INITRAMFS" 1>&2
        rm -f $INITRAMFS
        exit 1
    fi

    ((index++))
done

echo "Bundling all layers into a single CPIO archive: $DESTDIR/initramfs.cpio"
mv $INITRAMFS $DESTDIR/initramfs.cpio