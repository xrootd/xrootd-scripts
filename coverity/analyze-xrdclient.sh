#!/bin/bash

#-------------------------------------------------------------------------------
# Settings
#-------------------------------------------------------------------------------
PROJECT=XrdCl
STREAM=XrdCl
SRCDIR=/build/xrootd/src/xrdclient
BUILDDIR=/build/xrootd/src/xrdclient-build
INSTALLDIR=/build/xrootd/install/xrdclient
TMPDIR=/build/xrootd/analysis/
LOGFILE=/tmp/xrootd-coverity-`date +%Y%m%d-%H%M%S`.log
CONFCOMMAND="cmake $SRCDIR -DCMAKE_INSTALL_PREFIX=$INSTALLDIR -DXROOTD_DIR=/build/xrootd/install/xrootd -DCPPUNIT_DIR=/build/xrootd/utils/cppunit"
REPORTMAIL=ljanyst@cern.ch
LOGMAIL=ljanyst@cern.ch

source /afs/cern.ch/sw/lcg/external/gcc/4.5/x86_64-slc5/setup.sh
source /build/xrootd/utils/setup.sh

#-------------------------------------------------------------------------------
# Analysis
#-------------------------------------------------------------------------------
source /build/xrootd/bin/analyze.sh
