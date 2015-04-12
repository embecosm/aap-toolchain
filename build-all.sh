#!/bin/sh

# Build script for the AAP LLVM tool chain

# Copyright (C) 2009, 2013, 2014, 2015 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# This file is part of the Embecosm LLVM build system for AAP.

# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 3 of the License, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.

# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <http://www.gnu.org/licenses/>.
# This file is part of the Embecosm LLVM build system for AAP.

#		     SCRIPT TO BUILD AAP LLVM TOOL CHAIN
#		     ===================================

# Invocation Syntax

#     build-all.sh [--version-file <filename>]
#                  [--build-dir <build_dir>] [--install-dir <install_dir>]
#                  [--symlink-dir <symlink_dir>]
#                  [--clean | --no-clean]
#                  [--auto-pull | --no-auto-pull]
#                  [--auto-checkout | --no-auto-checkout]
#                  [--datestamp-install]
#                  [--jobs <count>] [--load <load>] [--single-thread]
#                  [--llvm | --no-llvm]
#                  [--gnu | --no-gnu]
#                  [--newlib | --no-newlib]
#                  [--gdbserver | --no-gdbserver]
#                  [--rebuild-libs]
#                  [--target-cflags]

# This script is a convenience wrapper to build the AAP LLVM tool chain. It
# is assumed that git repositories are organized as follows:

#   gdbserver
#   binutils-gdb
#   clang
#   llvm
#   toolchain

# With clang symbolically linked into the tools subdirectory of the llvm
# repository. The directory containing this is referred to as the "top level
# directory".

# On start-up, the top level directory is set to the parent of the directory
# containing this script (since this script is held in the top level of the
# toolchain repository.

# --version-file <filename>

#     Specify a filename to be included with branch specifications for the
#     repository as documented in the get-versions.sh script.

# --build-dir <build_dir>

#     The directory in which the tool chain will be built. It defaults to
#     bd-<release>. The LLVM tools are built in the llvm subdir and the GNU
#     tools in the GNU subdir.

# --install-dir <install_dir>

#     The directory in which both tool chains should be installed. If not
#     specified, defaults to the directory install-<release> in the top level
#     directory.

# --symlink-dir <symlink_dir>

#     If specified, the install directory will be symbolically linked to this
#     directory.

#     For example it may prove useful to install in a directory named with the
#     date and time when the tools were built, and then symbolically link to a
#     directory with a fixed name. By using the symbolic link in the users
#     PATH, the latest version of the tool chain will be used, while older
#     versions of the tool chains remain available under the dated
#     directories.

# --clean | --no-clean

#     If --clean is specified, build directories will be cleaned and all tools
#     will be configured anew. Otherwise build directories are preserved if
#     they exist, and only configured if not yet configured.

# --auto-checkout | --no-auto-checkout

#     If specified, a "git checkout" will be done in each component repository
#     to ensure the correct branch is checked out. If tool chain is built from
#     a source tarball then default is to not make a checkout. If tool chain is
#     built from a Git repository then default is to make a checkout.

# --auto-pull | --no-auto-pull

#     If specified, a "git pull" will be done in each component repository
#     after checkout to ensure the latest code is in use. Default is to pull.
#     If tool chain is built from a source tarball then default is to not pull.
#     If tool chain is built from a Git repository then default is to pull.

# --datestamp-install

#     If specified, this will append a date and timestamp to the install
#     directory name. (see the comments under --symlink-dir above for reasons
#     why this might be useful).

# --jobs <count>

#     Specify that parallel make should run at most <count> jobs. The default
#     is <count> equal to one more than the number of processor cores shown by
#     /proc/cpuinfo.

# --load <load>

#     Specify that parallel make should not start a new job if the load
#     average exceed <load>. The default is <load> equal to one more than the
#     number of processor cores shown by /proc/cpuinfo.

# --single-thread

#     Equivalent to --jobs 1 --load 1000. Only run one job at a time, but run
#     whatever the load average.

# --llvm | --no-llvm

#     If set, build Clang/LLVM (default --llvm).

# --gnu | --no-gnu

#     If set, build binutils/ld/GDB (default --gnu).

# --newlib | --no-newlib

#     If set, build newlib (default --newlib).

# --gdbserver | --no-gdbserver

#     If set, build gdbserver (default --gdbserver).

# --rebuild-libs

#     If set clean and rebuild libraries (newlib, libgloss, CompilerRT).
#     Default not set

# --target-cflags

#     Specify CFLAGS to be added when compiling the target libraries (newlib
#     and CompilerRT). Default "-Os -g".

# Where directories are specified as arguments, they are relative to the
# current directory, unless specified as absolute names.

#------------------------------------------------------------------------------
#
#			       Shell functions
#
#------------------------------------------------------------------------------

# Determine the absolute path name. This should work for Linux, Cygwin and
# MinGW.
abspath ()
{
    sysname=`uname -o`
    case ${sysname} in

	Cygwin*)
	    # Cygwin
	    if echo $1 | grep -q -e "^[A-Za-z]:"
	    then
		echo $1		# Absolute directory
	    else
		echo `pwd`\\$1	# Relative directory
	    fi
	    ;;

	Msys*)
	    # MingGW
	    if echo $1 | grep -q -e "^[A-Za-z]:"
	    then
		echo $1		# Absolute directory
	    else
		echo `pwd`\\$1	# Relative directory
	    fi
	    ;;

	*)
	    # Assume GNU/Linux!
	    if echo $1 | grep -q -e "^/"
	    then
		echo $1		# Absolute directory
	    else
		echo `pwd`/$1	# Relative directory
	    fi
	    ;;
    esac
}


# Print a header to the log file and console

# @param[in] String to use for header
header () {
    str=$1
    len=`expr length "${str}"`

    # Log file header
    echo ${str} >> ${logfile} 2>&1
    for i in $(seq ${len})
    do
	echo -n "=" >> ${logfile} 2>&1
    done
    echo "" >> ${logfile} 2>&1

    # Console output
    echo "${str} ..."
}


#------------------------------------------------------------------------------
#
#		     Argument handling and initialization
#
#------------------------------------------------------------------------------

# Sanity check
if ! python --version 2>&1 | grep 'Python 2' > /dev/null 2>&1
then
    echo "ERROR: Python version 2 not found"
    exit 1
fi

if ! cmake --version > /dev/null 2>&1
then
    echo "ERROR: cmake not installed"
    exit 1
fi

# Set the top level directory.
topdir=`pwd`/..

# Generic release set up. This defines (and exports RELEASE, LOGDIR and
# RESDIR, creating directories named $LOGDIR and $RESDIR if they don't exist.
. "${topdir}"/toolchain/define-release.sh

# Set defaults for some options
version_file=""
autocheckout="--auto-checkout"
autopull="--auto-pull"
doclean="--no-clean"
builddir="${topdir}/bd-${RELEASE}"
installdir="${topdir}/install-${RELEASE}"
symlinkdir=""
datestamp=""
dollvm="--llvm"
dognu="--gnu"
donewlib="--newlib"
dogdbserver="--gdbserver"
rebuildlibs="no"
target_cflags="-Os -g"

# Parse options
until
opt=$1
case ${opt} in
    --version-file)
	shift
	version_file="--version-file $1"
	;;

    --build-dir)
	shift
	mkdir -p $1
	builddir=$(abspath $1)
	;;

    --install-dir)
	shift
	installdir=$(abspath $1)
	;;

    --symlink-dir)
	shift
	symlinkdir=$(abspath $1)
	;;

    --clean | --no-clean)
	doclean=$1
	;;

    --auto-checkout | --no-auto-checkout)
	autocheckout=$1
	;;

    --auto-pull | --no-auto-pull)
	autopull=$1
	;;

    --datestamp-install)
	datestamp=`date -u +%F-%H%M`
	;;

    --jobs)
	shift
	jobs=$1
	;;

    --load)
	shift
	load=$1
	;;

    --single-thread)
	jobs=1
	load=1000
	;;

    --llvm | --no-llvm)
	dollvm=$1
	;;

    --gnu | --no-gnu)
	dognu=$1
	;;

    --newlib | --no-newlib)
	donewlib=$1
	;;

    --gdbserver | --no-gdbserver)
	dogdbserver=$1
	;;

    --rebuild-libs)
	rebuildlibs=$1
	;;

    --target-cflags)
	shift
	target_cflags="$1"
	;;

    ?*)
	echo "Unknown argument $1"
	echo
	echo "Usage: ./build-all.sh [--build-dir <build_dir>]"
        echo "                      [--install-dir <install_dir>]"
	echo "                      [--symlink-dir <symlink_dir>]"
	echo "                      [--clean | --no-clean]"
	echo "                      [--auto-checkout | --no-auto-checkout]"
        echo "                      [--auto-pull | --no-auto-pull]"
	echo "                      [--datestamp-install]"
	echo "                      [--jobs <count>] [--load <load>]"
        echo "                      [--single-thread]"
	echo "                      [--llvm | --no-llvm]"
	echo "                      [--gnu | --no-gnu]"
	echo "                      [--newlib | --no-newlib]"
	echo "                      [--rebuild-libs]"
	echo "                      [--target-cflags <flags>]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

# Set up a logfile
logfile="${LOGDIR}/all-build-$(date -u +%F-%H%M).log"
rm -f "${logfile}"
echo "Logging to ${logfile} ..."

# Create the build directories if necessary.
builddir_llvm=${builddir}/llvm
builddir_gnu=${builddir}/gnu
builddir_newlib=${builddir}/newlib
builddir_gdbserver=${builddir}/gdbserver

if [ "x${doclean}" = "x--clean" ]
then
    header "Cleaning build directories"

    if [ "x${dollvm}" = "x--llvm" ]
    then
	rm -rf ${builddir_llvm}
    fi

    if [ "x${dognu}" = "x--gnu" ]
    then
	rm -rf ${builddir_gnu}
    fi

    if [ \( "x${donewlib}" = "x--newlib" \) ]
    then
	rm -rf ${builddir_newlib}
    fi

    if [ \( "x${dogdbserver}" = "x--gdbserver" \) ]
    then
	rm -rf ${builddir_gdbserver}
    fi
fi

if [ "x${rebuildlibs}" = "x--rebuild-libs" ]
then
    header "Cleaning newlib build directory"
    rm -rf ${builddir_newlib}
fi

mkdir -p ${builddir_llvm}
mkdir -p ${builddir_gnu}
mkdir -p ${builddir_newlib}
mkdir -p ${builddir_gdbserver}

# Add a datestamp to the install directory if necessary. But if we are using
# --no-clean, we should reuse the installdir from the existing configuration.
if [ \( "x${doclean}" = "x--no-clean" \) -a \
     \( -e ${builddir_llvm}/CMakeCache.txt \) ]
then
    cd ${builddir_llvm}
    datestamp=""
    if grep 'CMAKE_INSTALL_PREFIX:PATH=' CMakeCache.txt > /dev/null 2>&1
    then
	installdir=`sed -n -e 's/CMAKE_INSTALL_PREFIX:PATH=//p' \
	    < CMakeCache.txt`
    fi
fi

if [ "x${datestamp}" != "x" ]
then
    installdir="${installdir}-$datestamp"
fi

# Sort out parallelism
make_load="`(echo processor; cat /proc/cpuinfo 2>/dev/null) \
           | grep -c processor`"

if [ "x${jobs}" = "x" ]
then
    jobs=${make_load}
fi

if [ "x${load}" = "x" ]
then
    load=${make_load}
fi

parallel="-j ${jobs} -l ${load}"

# Sort out target C flags
CFLAGS_FOR_TARGET="${target_cflags}"
export CFLAGS_FOR_TARGET

# Log the environment
header "Logging build environment"
echo "Environment variables:" >> "${logfile}" 2>&1
env >> "${logfile}" 2>&1
echo ""  >> "${logfile}" 2>&1

echo "Key script variables:" >> "${logfile}" 2>&1
echo "  autocheckout=${autocheckout}" >> "${logfile}" 2>&1
echo "  autopull=${autopull}" >> "${logfile}" 2>&1
echo "  doclean=${doclean}" >> "${logfile}" 2>&1
echo "  builddir=${builddir}" >> "${logfile}" 2>&1
echo "  installdir=${installdir}" >> "${logfile}" 2>&1
echo "  symlinkdir=${symlinkdir}" >> "${logfile}" 2>&1
echo "  datestamp=${datestamp}" >> "${logfile}" 2>&1
echo "  target_cflags=${target_cflags}" >> "${logfile}" 2>&1

# Checkout the correct branch for each tool
header "Checking out GIT trees"
if ! ${topdir}/toolchain/get-versions.sh ${topdir} ${version_file} \
        ${autocheckout} ${autopull} >> ${logfile} 2>&1
then
    echo "ERROR: Failed to checkout GIT versions of tools."
    echo "- see ${logfile}"
    exit 1
fi

#------------------------------------------------------------------------------
#
#				CLANG and LLVM
#
#------------------------------------------------------------------------------

if [ "x${dollvm}" = "x--llvm" ]
then
    # If Clang is not symlinked into the LLVM directory, we should do this first.
    if ! [ -e ${topdir}/llvm/tools/clang ]
    then
	ln -s ${topdir}/clang ${topdir}/llvm/tools/clang
    fi
    # Optionally configure Clang & LLVM. This should be generic for Linux,
    # Cygwin and MinGW. Only if we are doing a clean build or we haven't
    # previously configured.
    cd ${builddir_llvm}
    if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e CMakeCache.txt \) ]
    then
	header "Configuring Clang & LLVM"
	if ! cmake -DCMAKE_BUILD_TYPE=Debug -DLLVM_ENABLE_ASSERTIONS=ON \
                -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=${installdir} \
	        -G "Unix Makefiles" ../../llvm >> ${logfile} 2>&1
	then
	    echo "ERROR: Configuration of Clang & LLVM failed."
	    echo "- see ${logfile}"
	    exit 1
	fi
    fi

    # Build Clang & LLVM
    header "Building Clang & LLVM"
    cd ${builddir_llvm}
    if ! make ${parallel} >> ${logfile} 2>&1
    then
	echo "ERROR: Build of Clang & LLVM failed."
	echo "- see ${logfile}"
	exit 1
    fi

    # Link to the AAP specific compiler in the build directory
    header "Linking to built AAP compiler"

    cd ${builddir_llvm}/bin
    ln -sf clang aap-cc
    ln -sf clang++ aap-c++

    # Install Clang & LLVM
    header "Installing Clang & LLVM"
    cd ${builddir_llvm}
    if ! make install >> ${logfile} 2>&1
    then
	echo "ERROR: Install of Clang & LLVM failed."
	echo "- see ${logfile}"
	exit 1
    fi

    # Link to the AAP specific compiler in the install directory
    header "Linking to installed AAP compiler"

    cd ${installdir}/bin
    ln -sf clang aap-cc
    ln -sf clang aap-c++
fi

# Whether or not we built LLVM, we want it on our path
PATH=${installdir}/bin:$PATH
export PATH

#------------------------------------------------------------------------------
#
#				Binutils & GDB
#
#------------------------------------------------------------------------------

if [ "x${dognu}" = "x--gnu" ]
then
    # Optionally configure binutils and GDB. This should be generic for Linux,
    # Cygwin and MinGW. Only if we are doing a clean build or we haven't
    # previously configured.
    cd ${builddir_gnu}
    if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
    then
	header "Configuring binutils & GDB"
	if ! ${topdir}/binutils-gdb/configure --target=aap --with-gnu-as=no \
	        --prefix=${installdir} --disable-werror --disable-sim \
	        >> ${logfile} 2>&1
	then
	    echo "ERROR: Configuration of binutils & GDB failed."
	    echo "- see ${logfile}"
	    exit 1
	fi
    fi

    # Build binutils & GDB. For now don't try to do in parallel, but should
    # work (needs testing).
    header "Building binutils"
    cd ${builddir_gnu}
    if ! make all-binutils >> ${logfile} 2>&1
    then
	echo "ERROR: Build of binutils failed."
	echo "- see ${logfile}"
	exit 1
    fi

    header "Building ld"
    cd ${builddir_gnu}
    if ! make all-ld >> ${logfile} 2>&1
    then
	echo "ERROR: Build of ld failed."
	echo "- see ${logfile}"
	exit 1
    fi

    header "Building GDB"
    cd ${builddir_gnu}
    if ! make all-gdb >> ${logfile} 2>&1
    then
	echo "ERROR: Build of GDB failed."
	echo "- see ${logfile}"
	exit 1
    fi

    # Install binutils & GDB
    header "Installing binutils & GDB"
    cd ${builddir_gnu}
    if ! make install-binutils install-ld install-gdb >> ${logfile} 2>&1
    then
	echo "ERROR: Install of binutils & GDB failed."
	echo "- see ${logfile}"
	exit 1
    fi
fi

#------------------------------------------------------------------------------
#
#				    Newlib
#
#------------------------------------------------------------------------------

if [ "x${donewlib}" = "x--newlib" ]
then
    # Optionally configure Newlib. This should be generic for Linux, Cygwin
    # and MinGW. Only if we are doing a clean build or we haven't previously
    # configured.
    cd ${builddir_newlib}
    if [ \( "x${doclean}" = "x--clean" \) \
	-o \( "x${rebuildlibs}" = "x--rebuild-libs" \) \
	-o \( ! -e config.log \) ]
    then
	header "Configuring newlib"
	if ! ${topdir}/newlib/configure --target=aap --prefix=${installdir} \
            --disable-werror \
            --disable-newlib-atexit-dynamic-alloc \
            --enable-newlib-global-atexit \
            --enable-newlib-reent-small \
            --disable-newlib-fvwrite-in-streamio \
            --disable-newlib-fseek-optimization \
            --disable-newlib-wide-orient \
            --enable-newlib-nano-malloc \
            --enable-newlib-nano-formatted-io \
            --disable-newlib-unbuf-stream-opt \
            --enable-target-optspace \
            --disable-newlib-multithread \
            --enable-lite-exit \
            >> ${logfile} 2>&1
	then
	    echo "ERROR: Configuration of newlib failed."
	    echo "- see ${logfile}"
	    exit 1
	fi
    fi

    # Build newlib
    header "Building newlib"
    cd ${builddir_newlib}
    if ! make ${parallel} all-target-libgloss all-target-newlib \
	    >> ${logfile} 2>&1
    then
	echo "ERROR: Build of newlib failed."
	echo "- see ${logfile}"
	exit 1
    fi

    # Install newlib
    header "Installing newlib"
    cd ${builddir_newlib}
    if ! make install-target-libgloss install-target-newlib >> ${logfile} 2>&1
    then
	echo "ERROR: Install of newlib failed."
	echo "- see ${logfile}"
	exit 1
    fi
fi

#------------------------------------------------------------------------------
#
#                Compiler RT
#
#------------------------------------------------------------------------------

# Note that we need binutils for this to work.
if [ \( "x${dollvm}" = "x--llvm" \) \
    -o \( "x${rebuildlibs}" = "x--rebuild-libs" \) ]
then
    cd ${topdir}/compiler-rt
    header "Cleaning Compiler RT"
    if ! make -f AAP.mk clean >> ${logfile} 2>&1
    then
    echo "ERROR: Clean of Compiler RT failed"
    echo "- see ${logfile}"
    exit 1
    fi

    header "Building Compiler RT"
    if ! make EXTRA_CFLAGS="${target_cflags}" ${parallel} -f AAP.mk \
	      >> ${logfile} 2>&1
    then
    echo "ERROR: Build of Compiler RT failed"
    echo "- see ${logfile}"
    exit 1
    fi

    # Manually install
    header "Installing Compiler RT"
    if ! mkdir -p ${installdir}/aap/lib >> ${logfile} 2>&1
    then
    echo "ERROR: Failed to create install dir for Compiler RT"
    echo "- see ${logfile}"
    exit 1
    fi

    if ! cp libcompiler_rt.a ${installdir}/aap/lib >> ${logfile} 2>&1
    then
    echo "ERROR: Install of Compiler RT failed"
    echo "- see ${logfile}"
    exit 1
    fi
fi

#------------------------------------------------------------------------------
#
#				  gdbserver
#
#------------------------------------------------------------------------------

if [ "x${dogdbserver}" = "x--gdbserver" ]
then
    # Optionally configure gdbserver. This should be generic for Linux,
    # Cygwin and MinGW. Only if we are doing a clean build or we haven't
    # previously configured.
    cd ${builddir_gdbserver}
    if [ \( "x${doclean}" = "x--clean" \) -o \( ! -e config.log \) ]
    then
	header "Configuring gdbserver"
	if ! ${topdir}/gdbserver/configure --target=aap \
	     --prefix=${installdir} \
	     >> ${logfile} 2>&1
	then
	    echo "ERROR: Configuration of gdbserver failed."
	    echo "- see ${logfile}"
	    exit 1
	fi
    fi

    # Build gdbserver. For now don't try to do in parallel, but should
    # work (needs testing).
    header "Building gdbserver"
    cd ${builddir_gdbserver}
    if ! make  >> ${logfile} 2>&1
    then
	echo "ERROR: Build of gdbserver failed."
	echo "- see ${logfile}"
	exit 1
    fi

    # Install gdbserver
    header "Installing gdbserver"
    cd ${builddir_gdbserver}
    if ! make install >> ${logfile} 2>&1
    then
	echo "ERROR: Install of gdbserver failed."
	echo "- see ${logfile}"
	exit 1
    fi
fi

#------------------------------------------------------------------------------
#
#				Final tidy up
#
#------------------------------------------------------------------------------

# If we have a symlink dir, set it up.
if [ "x${symlinkdir}" != "x" ]
then
    header "Setting symbolic link to install directory"
    # Note that ln -sf does not do what the manual page says!
    rm -f ${symlinkdir}
    ln -s ${installdir} ${symlinkdir}
fi

echo "Build completed successfully."
exit 0
