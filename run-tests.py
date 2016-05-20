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

from concurrent.futures import ThreadPoolExecutor, as_completed
from glob import glob
from shutil import rmtree
from threading import Lock
from subprocess import Popen

import os
import sys

# Set names and locations of various things we interact with
TOPDIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TEST_SUITE = os.path.join(TOPDIR, 'gcc', 'gcc', 'testsuite')
TOOLCHAIN = os.path.join(TOPDIR, 'toolchain')
DG_EXTRACT_RESULTS = os.path.join(TOPDIR, 'gcc', 'contrib', 'dg-extract-results.py')
OVERRIDE_MANIFEST = os.path.join(TOOLCHAIN, 'override-manifest')
OUTPUT_DIR = os.path.join(TOOLCHAIN, 'test-output')
TEST_BOARD = 'aap-run'
RUNTEST_FLAGS = []

TEST_DIR = 'gcc.c-torture'
TEST_SET = 'execute'

# The number of tests to pass to a single Dejagnu invocation at once
DG_INSTANCE_NTESTS = 20

# How many DejaGnu instances are run concurrently
WORKERS = os.cpu_count()


class TestManager(object):
    '''
    The TestManager maintains the list of the tests that need to be run.
    '''
    def __init__(self):
        self._tests_lock = Lock()
        self._tests = None
        self._current_run = 0

    def find_tests(self, root):
        '''
        Find all .c files under the path root, relative to root.
        '''
        found = []
        for path, _, files in os.walk(root):
            found += [ os.path.relpath(os.path.join(path, name), start=root)
                           for name in files if name[-2:] == '.c' ]
        print("Discovered %s test files" % len(found))
        self._tests = found

    def pop_tests(self, ntests):
        '''
        Pop up to ntests tests from the list of tests. If there are less than
        ntests tests remaining, all the tests are popped.

        Returns i, t where i is a unique integer identifying the instance of
        dejagnu to be launched, and t is a list of test names.
        '''
        if self._tests is None:
            raise RuntimeError("Tests must be discovered first")
        self._tests_lock.acquire()

        t = []
        while self._tests and ntests:
            t.append(self._tests.pop())
            ntests -= 1

        i = self._current_run
        self._current_run += 1

        self._tests_lock.release()
        return i, t


def runtests_env():
    env = os.environ.copy()
    env['DEJAGNU'] = os.path.join(TOPDIR, "toolchain", "site.exp")
    return env

def runtests(i, tests):
    '''
    Launch instance i of DejaGnu, running the given list of tests
    '''
    # Prepare output directory
    dg_output_dir = os.path.join(OUTPUT_DIR, 'dgrun_%s' % i)
    os.mkdir(dg_output_dir)

    test_list = " ".join([ os.path.join(TEST_SET, test) for test in tests ])
    args = [
        'runtest',
        '--tool=gcc',
        '--directory=%s' % os.path.join(TEST_SUITE, TEST_DIR),
        '--srcdir=%s' % TEST_SUITE,
        '--override_manifest=%s' % OVERRIDE_MANIFEST,
        '%s.exp=%s' % (TEST_SET, test_list) ]
    args += RUNTEST_FLAGS

    proc = Popen(args, env=runtests_env(), cwd=dg_output_dir)
    return proc.wait()

def test_loop(tm=None):
    '''
    Repeatedly invoke DejaGnu with a list of tests obtained from the TestManager.

    Each worker thread runs this function until completion.
    '''
    if tm is None:
        raise ValueError("test_loop requires a TestManager")

    i, next_tests = tm.pop_tests(DG_INSTANCE_NTESTS)
    while next_tests:
        runtests(i, next_tests)
        i, next_tests = tm.pop_tests(DG_INSTANCE_NTESTS)


def combine_results(dg_outfile, *, extra_args=None):
    '''
    Combine the outputs of all DejaGnu instances using the dg-extract-results.py
    script from GCC.
    '''
    output_files = glob(os.path.join(OUTPUT_DIR, 'dgrun*/%s' % dg_outfile))
    args = [ sys.executable, DG_EXTRACT_RESULTS ]
    if extra_args is not None:
        args += extra_args
    args += output_files

    with open(os.path.join(OUTPUT_DIR, dg_outfile), 'w') as f:
        result = Popen(args, cwd=TOOLCHAIN, stdout=f)
        if result.wait():
            print("Warning: error combining %s" % dg_outfile, file=sys.stderr)

def combine_sums():
    combine_results('gcc.sum')

def combine_logs():
    combine_results('gcc.log', extra_args=['-L'])

def print_summary():
    '''
    Search the combined summary output for the count of each result,
    and print them.
    '''
    interesting = [
        '# of expected passes',
        '# of unexpected failures',
        '# of unexpected successes',
        '# of expected failures',
        '# of unknown successes',
        '# of known failures',
        '# of untested testcases',
        '# of unresolved testcases',
        '# of unsupported tests' ]

    with open(os.path.join(OUTPUT_DIR, 'gcc.sum')) as f:
        summary = [
            line for line in f
            for phrase in interesting
            if phrase in line ]

    print("\nTest summary:\n")
    print("".join(summary))


def main(args):
    # Prepare output directory
    if os.path.exists(OUTPUT_DIR):
        rmtree(OUTPUT_DIR)
    os.mkdir(OUTPUT_DIR)

    # Set up the test manager
    tm = TestManager()
    tm.find_tests(os.path.join(TEST_SUITE, TEST_DIR, TEST_SET))

    # Use a set of workers to execute tests in parallel
    executor = ThreadPoolExecutor(max_workers=WORKERS)
    jobs = {executor.submit(test_loop, **{'tm': tm}): i for i in range(WORKERS)}
    for worker in as_completed(jobs):
        try:
            worker.result()
        except Exception as exc:
            print("Job %s generated an exception: %s" % (worker, exc))

    # Combine the output from all instances
    combine_sums()
    combine_logs()

    print_summary()


if __name__ == '__main__':
    sys.exit(main(sys.argv))
