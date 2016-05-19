#!/bin/sh

# Clone script for the AAP LLVM tool chain

# Copyright (C) 2009, 2013, 2014, 2015, 2016 Embecosm Limited
# Contributor Jeremy Bennett <jeremy.bennett@embecosm.com>

# This file is part of the Embecosm LLVM build system.

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

#		      SCRIPT TO CLONE AN LLVM TOOL CHAIN
#		      ==================================

# Invocation Syntax

#     clone-all.sh [-dev]


# Do the cloning. $1 is the repo name

cloneit () {
    repo=$1

    cd ${topdir}
    if [ -d ${repo} ]
    then
	# Already exists, ignore unless it is not a git repo working dir
	if [ ! -d ${repo}/.git ]
	then
	    echo "ERROR: ${repo} exists, but is not a git working directory."
	    overall_res=255
	fi
    else
	echo "Cloning ${repo}..."
	branch="${ARCH}-master"
	repo_url=${BASE_URL}/${ARCH}-${repo}.git
	git clone -o ${UPSTREAM} -b ${branch}  ${repo_url} ${repo}
    fi
}

# Set the top level directory.
topdir=$(cd $(dirname $0)/..;pwd)

# Are we a developer?
if [ \( $# = 1 \) -a \( "x$1" = "x-dev" \) ]
then
    BASE_URL=git@github.com:embecosm
else
    BASE_URL=https://github.com/embecosm
fi

# Architecture prefix
ARCH=aap

# Upstream repo name
UPSTREAM=github

# Set the overall status so far
overall_res=0

# Clone all the (other) repos
cloneit binutils-gdb
#cloneit beebs
cloneit clang
#cloneit clang-tests
cloneit compiler-rt
#cloneit documentation
cloneit gdbserver
cloneit llvm
cloneit newlib

# Any postprocessing
cd ${topdir}/llvm/tools
if [ ! -L clang ]
then
    echo "Linking Clang into LLVM"
    ln -sf ../../clang .
fi

exit ${overall_res}
