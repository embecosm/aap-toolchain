#!/bin/sh

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

#		SCRIPT TO DEFINE RELEASE SPECIFIC INFORMATION
#               =============================================

# Script must be sourced, since it sets up environment variables for the
# parent script.

# Defines the RELEASE, LOGDIR and RESDIR environment variables, creating the
# LOGDIR and RESDIR directories if they don't exist.

# Usage:

#     . define-release.sh

# The variable ${topdir} must be defined, and be the absolute directory
# containing all the repositories.

if [ "x${topdir}" = "x" ]
then
    echo "define-release.sh: Top level directory not defined."
    exit 1
fi

# The release number
RELEASE=master

# Create a common log directory for all logs
LOGDIR=${topdir}/logs-${RELEASE}
mkdir -p ${LOGDIR}

# Create a common results directory in which sub-directories will be created
# for each set of tests.
RESDIR=${topdir}/results-${RELEASE}
mkdir -p ${RESDIR}

# Export the environment variables
export RELEASE
export LOGDIR
export RESDIR
