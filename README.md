# OCI Image to CPIO Archive Script

This script downloads an OCI (Open Container Initiative) image from a remote repository and converts the image layers into CPIO archives. It uses the `skopeo` tool to fetch the image and `bsdtar` to create the CPIO archives.

## Prerequisites

Before using this script, ensure you have the following tools installed:

- `skopeo`: For copying container images between registries or from a registry to a directory.
- `jq`: For processing JSON data.
- `bsdtar`: For creating CPIO archives.

You can install these tools using your package manager.