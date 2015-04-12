#!/bin/sh

# Script to pull and check out git repositories for the AAP LLVM tool chain

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

# -----------------------------------------------------------------------------
# Usage:

#     get-versions.sh <topdir>
#                     [--version-file <filename>]
#                     [--auto-checkout | --no-auto-checkout]
#                     [--auto-pull | --no-auto-pull]

# Arguments

# <topdir>

#     The top level directory, i.e. the one containing all the repositories.

# --version-file <filename>

#     Name of a file to include specifying versions of tools to use.  If
#     omitted, all repositories default to the "aap-master" branch.  If a file
#     is given, only those repos with different branches to the default need
#     be specified.  If the file does not exist it is ignored with a warning.
#     If not absolute filenames are relative to the toolchain repository
#     directory within <topdir>.

# --auto-checkout | --no-auto-checkout

#     Control whether to checkout each branch.  Default --auto-checkout.  Can
#     be used with --auto-pull to get the latest version of the repo, witout
#     changing the currently checked out branches.

# --auto-pull | --no-auto-pull

#     Control whether to pull each repository.  Default --auto-pull.  Can be
#     useful when working without a network connection to just check out the
#     desired repos.

# The mandatory first argument is the directory within which the GIT trees
# live.

# We checkout the desired branch for each tool. Note that these must exist or
# we fail. Leaving partially completed changes around may also cause failure.

# Default options
version_file=""
autocheckout="--auto-checkout"
autopull="--auto-pull"

# Top level directory
topdir=$1
shift

if [ "x${topdir}" = "x" ]
then
    echo "get-versions.sh: No top level directory specified."
    exit 1
fi

# Parse options
until
opt=$1
case ${opt} in
    --version-file)
	shift
	version_file=$1
	;;

    --auto-checkout | --no-auto-checkout)
	autocheckout=$1
	;;

    --auto-pull | --no-auto-pull)
	autopull=$1
	;;

    ?*)
	echo "Usage: get-versions.sh  <topdir>"
	echo "                        [--version-file <filename>]"
	echo "                        [--auto-checkout | --no-auto-checkout]"
        echo "                        [--auto-pull | --no-auto-pull]"
	exit 1
	;;

    *)
	;;
esac
[ "x${opt}" = "x" ]
do
    shift
done

# Specify the default versions to use as a string <tool>:<branch>.
binutils_gdb="binutils-gdb:aap-master"
clang="clang:aap-master"
llvm="llvm:aap-master"
compiler_rt="compiler-rt:aap-master"
newlib="newlib:aap-master"
#clang_tests="clang-tests:aap-master"
gdbserver="gdbserver:master"

# Modify these values accordingly
cd ${topdir}/toolchain

if [ "x${version_file}" != "x" ]
then
    if [ -e "${version_file}" ]
    then
	# Deal with sh search path issues
	f=`readlink -f ${version_file}`
	. ${f}
    else
	echo "Warning: Version file \`${version_file}' not found"
    fi
fi

# We have to deal with the possibility that we may currently be on a detached
# HEAD (so cannot fetch), or we want to checkout a detached HEAD (e.g. a
# tag). We also need to deal with the case that the branch we wish to checkout
# is not yet in the local repo, so we need to fetch before checking out.

# The particularly awkward case is when we are detached, and want to checkout
# a branch which is not yet in the local repo. In this case we must checkout
# some other branch, then fetch, then checkout the branch we want. This has a
# performance penalty, but only when coming from a detached branch.

# In summary the steps are:
# 1. If we are in detached HEAD state, checkout some arbitrary branch.
# 2. Fetch (in case new branch)
# 3. Checkout the branch
# 4. Pull unless we are in a detached HEAD state.

# Steps 1, 2 and 4 are only used if we have --auto-pull enabled.

# All this will go horribly wrong if you leave uncommitted changes lying
# around or if you change the remote. Nothing then but to sort it out by hand!
for version in ${binutils_gdb} ${clang} ${llvm} ${compiler_rt} ${newlib} \
               ${clang_tests} ${gdbserver}
do
    tool=`echo ${version} | cut -d ':' -f 1`
    branch=`echo ${version} | cut -d ':' -f 2`
    cd ${topdir}/${tool}

    echo "Checking out branch/tag ${branch} of ${tool}"

    if [ "x${autopull}" = "x--auto-pull" ]
    then
        # If tree is in detached state, output differs between Git versions:
        # Git 1.8 prints: * (detached from <tag_name>>)
        # Git <1.8 prints: * (no branch)
	if git branch | grep -q -e '\* (detached from .*)' -e '\* (no branch)'
	then
	    # Detached head. Checkout an arbitrary branch
	    arb_br=`git branch | grep -v '^\*' | head -1`
	    echo "  detached HEAD, interim checkout of ${arb_br}"
	    if ! git checkout ${arb_br} > /dev/null 2>&1
	    then
		exit 1
	    fi
	fi
	# Fetch any new branches
	echo "  fetching branches"
	if ! git fetch
	then
	    exit 1
	fi
	# Fetch any new tags
	echo "  fetching tags"
	if ! git fetch --tags
	then
	    exit 1
	fi
    fi

    if [ "x${autocheckout}" = "x--auto-checkout" ]
    then
	echo "  checking out ${branch}"
	if ! git checkout ${branch}
	then
	    echo "Directory "`pwd`
	    echo "Branch \"${branch}\""
	    exit 1
	fi
    fi

    if [ "x${autopull}" = "x--auto-pull" ]
    then
        # Only update to latest if we are not in detached HEAD mode. See note
	# above for different messages depending on git version.
        if ! git branch | grep -q -e '\* (detached from .*)' -e '\* (no branch)'
        then
            echo "  pulling latest version"
            if ! git pull
            then
                exit 1
            fi
        fi
    fi
done
