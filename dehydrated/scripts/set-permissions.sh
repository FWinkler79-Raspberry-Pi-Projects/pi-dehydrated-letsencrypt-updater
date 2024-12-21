#!/usr/bin/env bash

# Set permissions for the certififactes folder and subfolders and files.
# Make it accessible to everyone in read-only fashion.
echo "Setting read-only permissions for everyone on certificates folder and subfolders."
chmod -R a+rx /dehydrated/certificates
