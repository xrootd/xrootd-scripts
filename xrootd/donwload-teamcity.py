#!/usr/bin/env python
#-------------------------------------------------------------------------------
# Author: Lukasz Janyst <ljanyst@cern.ch>
# Description: Download the release RPMs from teamcity and sort them into
#              directories
#-------------------------------------------------------------------------------

import sys
import os
import getopt
import mechanize
import lxml.etree
import tempfile
import urllib
import zipfile
import shutil
import hashlib
import subprocess

#-------------------------------------------------------------------------------
# Some variables
#-------------------------------------------------------------------------------
BASE_URL="https://teamcity-dss.cern.ch:8443"
CONFIG='/guestAuth/app/rest/buildTypes/id:'
PROJECT='/guestAuth/app/rest/projects/id:XRootD'
ARTIFACTS_PREFIX='/guestAuth/repository/downloadAll/'
ARTIFACTS_SUFFIX=':id/artifacts.zip'

sysMap = {}
sysMap['slc5'] = {'i386': 'slc-5-i386', 'x86_64': 'slc-5-x86_64'}
sysMap['slc6'] = {'i386': 'slc-6-i386', 'x86_64': 'slc-6-x86_64'}

#-------------------------------------------------------------------------------
class OpError(Exception):
    pass

#-------------------------------------------------------------------------------
class ConfigError(Exception):
    pass

#-------------------------------------------------------------------------------
def buildTagDict( configID ):
    """Build tag-url dictionary"""
    #    print configURL
    configURL = BASE_URL + CONFIG + configID + '/builds/'
    br = mechanize.Browser()
    response = br.open( configURL )
    doc = lxml.etree.fromstring( response.read() )
    buildList = doc.xpath( '//build' )
    tagDict = {}
    for build in buildList:
        response = br.open( BASE_URL + build.attrib['href'] )
        buildDoc = lxml.etree.fromstring( response.read() )
        tag = buildDoc.xpath( '//tag[1]/text()' )
        if tag:
            tag = tag[0]
            tagDict[tag] = BASE_URL+ARTIFACTS_PREFIX+configID+'/'+build.attrib['id']+ARTIFACTS_SUFFIX
    return tagDict

#-------------------------------------------------------------------------------
def buildConfigDict():
    """Build a list of configurations"""
    br = mechanize.Browser()
    response = br.open( BASE_URL + PROJECT )
    doc = lxml.etree.fromstring( response.read() )
    buildTypes = doc.xpath( '/project/buildTypes/buildType' )
    configDict = {}
    for buildType in buildTypes:
        configDict[buildType.get("name")] = buildType.get("id")
    return configDict

#-------------------------------------------------------------------------------
def getConfigId( opts ):
    if opts.has_key( '--configid' ):
        configID = opts['--configid']
    elif opts.has_key( '--config' ):
        configDict = buildConfigDict()
        try:
            configName = opts['--config']
            configID = configDict[configName]
        except KeyError, e:
            raise OpError( 'Config name is invalid' )
    else:
        raise OpError( 'Either config or configid needs to be specified' )

    return configID

#-------------------------------------------------------------------------------
def listTags( opts ):
    """List the available tags"""

    configID = getConfigId( opts )
    tagDict = buildTagDict( configID )
    for tag, url in tagDict.items():
        print tag, url

#-------------------------------------------------------------------------------
def listConfigs( opts ):
    """List available configurations"""
    configDict = buildConfigDict()
    for name, cid in configDict.items():
        print cid, name

#-------------------------------------------------------------------------------
def writeMD5Sums( directory, destFile ):
    """Generate the checksum file"""
    dirList = os.listdir( directory )
    sums = []
    for f in dirList:
        md5 = hashlib.md5()
        with open( '/'.join( [directory, f] ), 'rb' ) as input:
            for chunk in iter(lambda: input.read(8192), b''): 
                md5.update( chunk )
        sums.append( (f, md5.hexdigest()) )
    with open( destFile, 'w' ) as f:
        for sm in sums:
            f.write( sm[1] + ' ' + sm[0] + '\n' )

#-------------------------------------------------------------------------------
def sign( directory ):
    """Sign all the RPM files in the directory"""
    dirList = os.listdir( directory )
    files = map( lambda x: '/'.join([directory, x]), dirList )
    subprocess.call(["rpm", "--resign", "--define",  "_gpg_name xrootd-dev@slac.stanford.edu"]+files)

#-------------------------------------------------------------------------------
def unpack( opts ):
    """Unpack the artifacts"""

    #---------------------------------------------------------------------------
    # Select the tag to download
    #---------------------------------------------------------------------------
    configID = getConfigId( opts )
    try:
        tagName = opts['--tag']
        tagDict = buildTagDict( configID )
        url = tagDict[tagName]
    except KeyError, e:
        raise OpError( 'Tag name not specified or invalid' )

    #---------------------------------------------------------------------------
    # Download the file
    #---------------------------------------------------------------------------
    tmpDir = tempfile.mkdtemp()
    webFile = urllib.urlopen(url)
    localFile = open( tmpDir + '/artifacts.zip', 'w')
    localFile.write(webFile.read())
    webFile.close()
    localFile.close()

    #---------------------------------------------------------------------------
    # Unzip the artifacts
    #---------------------------------------------------------------------------
    z = zipfile.ZipFile( tmpDir + '/artifacts.zip' )
    for f in z.namelist():
        z.extract(f, tmpDir)

    #---------------------------------------------------------------------------
    # Move the files to the current dir
    #---------------------------------------------------------------------------
    for system, archs in sysMap.items():
        os.mkdir( system )
        for arch, path in archs.items():
            newPath = '/'.join( [system, arch] )
            oldPath = '/'.join( [tmpDir, path] )
            os.mkdir( newPath )
            dirList = os.listdir( oldPath )
            dirList.remove( 'logs' )
            dirList.remove( 'manifest.txt' )
            dirList = filter( lambda x: not x.endswith( 'src.rpm' ), dirList )
            dirList = filter( lambda x: not x.startswith( 'xrootd4-tests' ), dirList )
            for name in dirList:
                shutil.copy( '/'.join( [oldPath, name] ), newPath )
            if newPath.startswith('slc6'):
                sign( newPath )
            writeMD5Sums( newPath, '/'.join( [newPath, 'md5sums'] ) )

#-------------------------------------------------------------------------------
def printHelp():
    """Print help"""
    print( 'GetReleaseFiles.py [options]' )
    print( ' --tag=tagName           tag name' )
    print( ' --config=configName     configuration name' )
    print( ' --configid=cid          configuration id' )
    print( ' --list-tags             list tags' )
    print( ' --list-configs          list build configurations in the project' )
    print( ' --unpack                unpack the artifacts to the current dir' )
    print( ' --help                  this help message' )

#-------------------------------------------------------------------------------
def main():
    """Run the show"""

    #---------------------------------------------------------------------------
    # Parse the commandline and print help if needed
    #---------------------------------------------------------------------------
    try:
        params = ['tag=', 'list-tags', 'unpack', 'help', 'list-configs',
                  'config=', 'configid=']
        optlist, args = getopt.getopt( sys.argv[1:], '', params )
    except getopt.GetoptError, e:
        print '[!]', e
        return 1

    opts = dict(optlist)
    if '--help' in opts or not opts:
        printHelp()
        return 0

    #---------------------------------------------------------------------------
    # Call the appropriate command
    #---------------------------------------------------------------------------
    commandMap = {'--list-tags': listTags, '--unpack': unpack,
                  '--list-configs': listConfigs }
    for command in commandMap:
        if command in opts:
            try:
                return commandMap[command]( opts )
            except ConfigError, e:
                print '[!]', e
                return 1
            except OpError, e:
                print '[!]', e
                return 1

if __name__ == '__main__':
    sys.exit(main())
