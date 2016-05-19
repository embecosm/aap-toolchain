#!/usr/bin/env python3

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

# This script assumes that clone-all.sh and build-all.sh have been run and
# completed successfully, and that gcc is cloned next to the other repositories
# with the test-override branch checked out.

import os
import subprocess

TOPDIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TEST_SUITE = os.path.join(TOPDIR, 'gcc', 'gcc', 'testsuite')
TEST_BOARD = 'aap-run'
RUNTEST_FLAGS = []

TEST_DIR = 'gcc.c-torture'
TEST_SET = 'execute.exp'

def runtests_env():
    env = os.environ.copy()
    env['DEJAGNU'] = os.path.join(TOPDIR, "toolchain", "site.exp")
    return env

def runtest():
    args = [
        'runtest',
        '--tool=gcc',
        '--directory=%s' % os.path.join(TEST_SUITE, TEST_DIR),
        '--srcdir=%s' % TEST_SUITE,
        '--override_manifest=override-manifest',
        TEST_SET ]
    args += RUNTEST_FLAGS
    proc = subprocess.Popen(args, env=runtests_env())
    return proc.wait()

def main(args):
    runtest()

if __name__ == '__main__':
    import sys
    sys.exit(main(sys.argv))
