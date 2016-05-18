#!/bin/bash

# Copyright (C) 2016 Embecosm Limited
# Contributor Graham Markall <graham.markall@embecosm.com>

# This file is a script to run the GCC testsuite on AAP using the AAP Simulator,
# aap-run.

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

# This script assumes that build-all.sh has been run and completed successfully,
# and that gcc is cloned next to the other repositories with the test-override
# branch checked out.

# Set the top level directory.
d=`dirname "$0"`
topdir=`(cd "$d/.." && pwd)`

export DEJAGNU=${topdir}/toolchain/site.exp
export testsuite=${topdir}/gcc/gcc/testsuite
export test_board=aap-run
export runtestflags=""

# Presently we only attempt to run the gcc.c-torture tests
export srcdir=${testsuite}
export test_dir="gcc.c-torture"
export test_set="execute.exp"

runtest --tool=gcc \
        --target-board=${test_board} \
        --directory=${srcdir}/${test_dir} \
        --srcdir=${srcdir} \
        ${runtestflags} \
        ${test_set}
