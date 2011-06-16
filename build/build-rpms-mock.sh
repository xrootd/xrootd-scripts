#!/bin/bash
#-------------------------------------------------------------------------------
# Desc: Build the RPMS from a given source
# Author: Lukasz Janyst <ljanyst@cern.ch>
#-------------------------------------------------------------------------------

function buildPlatform()
{
  PLATFORM=$1
  RPM=$2
  DEST=$3
  DEFINES=$4

  if [ ! -d $DEST/$PLATFORM ]; then
    mkdir -p $DEST/$PLATFORM;
    if [ $? -ne 0 ]; then
      echo "[!] Unable to create the destination directory: $DEST/$PLATFORM"
      return 1
    fi
  fi

  eval sudo -u build /usr/bin/mock rebuild $DEFINES -r $PLATFORM $RPM
  if [ $? -ne 0 ]; then
    echo "[!] Build failed!"
    return 1
  fi

  cp /var/lib/mock/$PLATFORM/result/*.rpm $DEST/$PLATFORM
}

#-------------------------------------------------------------------------------
# Check the parameters
#-------------------------------------------------------------------------------
if [ $# -lt 2 ]; then
  echo "[!] Usage: $0 xxx.src.rpm PLATFORM1,PLATFORM2 '--define DEFINE1 --define DEFINE2 ...'"
  exit 1
fi

if [ ! -r $1 ]; then
  echo "[!] $1 does not exist"
  exit 2
fi

#-------------------------------------------------------------------------------
# Decode platforms
#-------------------------------------------------------------------------------
SOURCERPM=$1
PLATFORMS=${2//,/ }
DEFINES=$3
echo "[i] Building for platforms: $PLATFORMS"
echo "[i] Extra defines: $DEFINES"

for PLATFORM in $PLATFORMS; do
  echo "[i] Building for $PLATFORM"
  buildPlatform $PLATFORM $SOURCERPM ./build "$DEFINES"
done
