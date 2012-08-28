#!/bin/bash

#-------------------------------------------------------------------------------
# Settings
#-------------------------------------------------------------------------------
PROJECT=XRootD-current
STREAM=XRootD-current
SRCDIR=/build/xrootd/src/xrootd
BUILDDIR=/build/xrootd/src/xrootd-build
INSTALLDIR=/build/xrootd/install/xrootd
TMPDIR=/build/xrootd/analysis/
LOGFILE=/tmp/xrootd-coverity-`date +%Y%m%d-%H%M%S`.log
CONFCOMMAND="cmake $SRCDIR -DCMAKE_INSTALL_PREFIX=$INSTALLDIR"
REPORTMAIL=xrootd-dev@slac.stanford.edu
LOGMAIL=ljanyst@cern.ch

source /afs/cern.ch/sw/lcg/external/gcc/4.5/x86_64-slc5/setup.sh
source /build/xrootd/utils/setup.sh

#-------------------------------------------------------------------------------
# Analysis
#-------------------------------------------------------------------------------
source /build/xrootd/bin/analyze.sh
