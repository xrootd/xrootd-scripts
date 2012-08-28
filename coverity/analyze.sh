#!/bin/bash

#-------------------------------------------------------------------------------
# Variables
#-------------------------------------------------------------------------------
CA=/build/axel/Coverity/cov-sa/bin/cov-analyze
CB=/build/axel/Coverity/cov-sa/bin/cov-build
CC=/build/axel/Coverity/cov-sa/bin/cov-commit-defects
CM=/build/axel/Coverity/cov-sa/bin/cov-manage-im
USERNAME=user
PASSWORD=password
TMPDIR=$TMPDIR/$STREAM

#-------------------------------------------------------------------------------
# Logging functions
#-------------------------------------------------------------------------------
function log()
{
    echo `date +"%F %T"`: "$@" >> $LOGFILE
}

function echoLog()
{
    echo $@
    log $@
}

function mailLog()
{
    cat $LOGFILE | mail -s "COVERITY: $STREAM - `date "+%F %T"` at `hostname`" \
	$LOGMAIL
}

#-------------------------------------------------------------------------------
# Run a command and fail with a message if unsuccessful
#-------------------------------------------------------------------------------
function run()
{
    if [ $# -le 1 ]; then
	echo "[!] Run function requires at least the message and the command"
	exit 1
    fi

    MESSAGE=$1
    shift
    OUTPUT=`eval $@ 2>&1`
    if [ $? -ne 0 ]; then
	echo $MESSAGE
	log "[$@]: $OUTPUT"
	mailLog
	exit 1
    fi
}

echoLog "[I] Running coverity analysis on XRootD"

#-------------------------------------------------------------------------------
# Check the existance of the execs and directories
#-------------------------------------------------------------------------------
if [ ! -x $CA ]; then
    echoLog "[!] Cannot find or execute $CA"
    exit 1
fi

if [ ! -x $CB ]; then
    echoLog "[!] Cannot find or execute $CB"
    exit 1
fi

if [ ! -x $CC ]; then
    echoLog "[!] Cannot find or execute $CC"
    exit 1
fi

run "[!] Cannot remove the temp directory" rm -rf $TMPDIR
run "[!] Cannot create temp directory" mkdir -p $TMPDIR
run "[!] Cannot remove the temp directory" rm -rf $BUILDDIR
run "[!] Cannot create temp directory" mkdir -p $BUILDDIR

if [ ! -d "$SRCDIR" ]; then
    echoLog "[!] Source directory does not exist: $SRCDIR"
    exit 1
fi

echoLog "[I] Using stream: $STREAM"

#-------------------------------------------------------------------------------
# Do an git checkout
#-------------------------------------------------------------------------------
cd $SRCDIR
run "[!] Unable to fetch the changes from the repository" git fetch

CHANGES="`git log --format='%H' HEAD..FETCH_HEAD`"
if [ x"$CHANGES" = x"" ]; then
    echoLog "[I] No changes to test"
    mailLog
    exit 0
fi

run "[!] Unable to reset the head" git reset --hard FETCH_HEAD

#-------------------------------------------------------------------------------
# Test build the source
#-------------------------------------------------------------------------------
echoLog "[I] Building the source..."
cd $BUILDDIR
run "[!] Unable to remove the installation dir" rm -rf $INSTALLDIR
run "[!] Unable to run configuration" $CONFCOMMAND
run "[!] Unable to clean the source" make clean
run "[!] Build failed" make -j4
run "[!] Installation failed" make install

#-------------------------------------------------------------------------------
# Run a coverity build
#-------------------------------------------------------------------------------
echoLog "[I] Doing coverity build..."
cd $BUILDDIR
run "[!] Unable to clean the source" make clean
run "[!] Coverity build failed" $CB --dir $TMPDIR/cov-out make -j4

if [ "`cat $TMPDIR/cov-out/build-log.txt | grep 100%`" == "" ]; then
    echoLog "[W] Not all sources were built correctly, check the build log"
fi

#-------------------------------------------------------------------------------
# Run the coverity analysis
#-------------------------------------------------------------------------------
CHK=(`$CA --list-checkers | grep -v 'Available ' | grep -v symbian | grep -v -E '^COM\.' | grep -v -E '^MISRA_CAST ' | grep -v -E '^USER_POINTER '  | grep -v -E '^INTEGER_OVERFLOW ' | grep -v -E '^STACK_USE ' | sed 's, (.*$,,'`)

for chk in ${CHK[*]}; do
    CHECKERS="$CHECKERS --enable $chk"
done

echoLog "[I] Running the analysis..."
run "[!] Analysis failed" $CA --disable-default --dir $TMPDIR/cov-out $CHECKERS --enable-callgraph-metrics --enable-parse-warnings --enable-single-virtual --enable-constraint-fpp --checker-option \
CONSTANT_EXPRESSION_RESULT:report_bit_and_with_zero:true --checker-option CONSTANT_EXPRESSION_RESULT:report_constant_logical_operands:true 

echoLog "[I] Uploading the defects to the web interface..."
run "[!] Web interface upload failed" $CC --host coverity-sft --user $USERNAME --password $PASSWORD --stream $STREAM --strip-path $SRCDIR --dir $TMPDIR/cov-out
echoLog "[I] Done"

#-------------------------------------------------------------------------------
# Generate report
#-------------------------------------------------------------------------------
echoLog "[I] Generating report..."
$CM --host coverity-sft --user $USERNAME --password $PASSWORD --mode defects --show --project $PROJECT --status New --fields cid,file,function,checker > $BUILDDIR/issues
ISSUESCOUNT=`wc -l $BUILDDIR/issues | cut -f 1 -d " "`
ISSUES=`cat $BUILDDIR/issues`
echoLog "[I] Done"

#-------------------------------------------------------------------------------
# Mailing the results
#-------------------------------------------------------------------------------
mailLog
echo -e "Hello,

   Your recent commits have been analysed by COVERITY and the
result is available at https://coverity.cern.ch There are $ISSUESCOUNT
outstanding issues.

Yours sincerely,
   The Coverity Bot

$ISSUES" | mail -s "COVERITY: $STREAM - `date "+%F %T"` at `hostname`" \
$REPORTMAIL
