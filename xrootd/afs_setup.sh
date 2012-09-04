#!/bin/bash

BASE_PATH=/afs/cern.ch/project/xrootd/software
GCC_BASE_PATH=/afs/cern.ch/sw/lcg/external/gcc/

#-------------------------------------------------------------------------------
# Check out the input and determine which version we need to set up
#-------------------------------------------------------------------------------
if test $# -lt 1 -a ! "$XROOTD_VERSION"; then
  echo "[!] You need to specify version you want to use."
  echo "[!] Either on the commandline:"
  echo "[!] ie: . ./setup.sh lcg/3.1.0p2/x86_64-slc5-gcc43-opt"
  echo "[!] Or by exporting an environment variable:"
  echo "[!] ie: export XROOTD_VERSION=lcg/3.1.0p2/x86_64-slc5-gcc43-opt"
  return
fi

if test $# -ge 1; then
  XROOTD_VERSION=$1
fi

if test ! -d $BASE_PATH/$XROOTD_VERSION/bin; then
  echo "[!] Version ${XROOTD_VERSION} not found"
  return
fi

echo "[i] Setting up xrootd version: ${XROOTD_VERSION}"

#-------------------------------------------------------------------------------
# Check out the architecture and compiler version that needs to be set up
#-------------------------------------------------------------------------------
ARCH=`basename $XROOTD_VERSION`

GCC_VER="`echo ${ARCH} | cut -d'-' -f3`"
GCC_VER="`echo ${GCC_VER} | awk '{print substr($0,4,1) "." substr($0,5,1)}'`"
CPU="`echo ${ARCH} | cut -d'-' -f1`"
OS="`echo ${ARCH} | cut -d'-' -f2`"

echo "[i] CPU Arch:    ${CPU}"
echo "[i] OS Type:     ${OS}"
echo "[i] GCC Version: ${GCC_VER}"

if test x"${CPU}" = x"x86_64"; then
  LIBDIR=lib64
else
  LIBDIR=lib
fi

#-------------------------------------------------------------------------------
# Check if gcc for the architecture exists in the lcg installation area
#-------------------------------------------------------------------------------
GCC_LIBDIR=${GCC_BASE_PATH}/${GCC_VER}/${CPU}-${OS}/${LIBDIR}
if test ! -d ${GCC_LIBDIR}; then
  echo "[!] Unable to find matching compiler libs: ${GCC_LIBDIR}"
  return
fi

echo "[i] Setting up the GCC libdir: ${GCC_LIBDIR}"
export LD_LIBRARY_PATH=${GCC_LIBDIR}:${LD_LIBRARY_PATH}
echo "[i] Set up the xrootd paths: ${BASE_PATH}/${XROOTD_VERSION}"
export PATH=${BASE_PATH}/${XROOTD_VERSION}/bin:${PATH}
export LD_LIBRARY_PATH=${BASE_PATH}/${XROOTD_VERSION}/${LIBDIR}:${LD_LIBRARY_PATH}
