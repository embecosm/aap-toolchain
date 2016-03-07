#!/bin/sh
# we can only rely one one argument without whitespace for interpreter scripts
/bin/sh -c '/usr/bin/env python2 -u' <<EOF

# Copyright (C) 2015 Embecosm Limited
# Contributor Simon Cook <simon.cook@embecosm.com>

# This file is a script to run GCC regression against a LLVM toolchain with GDB

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

import glob, os, subprocess, signal, threading, time

########################
# CONFIG, TO BE EDITED
########################
test_board = 'aap-sim'
max_tests = 8
rsp_start = 51000
timeout = 10
stack_size = 4096
text_size = 32768
# Basedir is the parent directory of this file
# e.g. if run-tests.py is in /home/user/aap/toolchain, basedir is /home/user/aap
basedir = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
startdir = basedir + '/toolchain'
DEJAGNU = startdir + '/site.exp'
srcdir = basedir + '/gcc-tests/gcc/testsuite'
resdir = basedir + '/gcc-results/' + time.strftime('%F-%H%M')


############################################
# MULTIPROCESS HANDLING AND TEST SCHEDULING
############################################

# List of processes we are tracking
processes = []
# Tests yet to run
tests_to_run = []
# Servers in the system
servers={}
test_count = 0
# Lock for interrupts
TIME_LOCK  = threading.Lock()

# Find the next available gdbserver
def get_next_server():
  for k in servers.keys():
    if servers[k]['running'] == False:
      check_server_up(k)
      return k
  print servers
  raise ValueError  # This should never happen

# Check that the server is running, if not relaunch it
def check_server_up(k):
  if servers[k]['process'].poll() is not None:
    servers[k]['process'] = launch_gdbserver(k[1:])
    print 'Warning: Relaunching gdbserver on', k, 'pid is', servers[k]['process'].pid  

# Function for handling test completion
# (This function is called upon a child process exiting (SIGCHLD). A
#  lock is used to ensure a level of thread-safeness that should allow all
#  tests to run to completion)
def test_finished(signum, frame):
  global TIME_LOCK
  os.waitpid(-1, os.WNOHANG)

  if TIME_LOCK.acquire(False):
    #for k in servers.keys():
    #  check_server_up(k)

    for p in processes:
      if p['proc'].poll() is not None:
        time_taken = time.time() - p['time']
        print 'PID', p['proc'].pid, '(' + p['test'] + ') has exited (took ' + \
              str(time_taken), 'seconds)'
        servers[p['server']]['running'] = False
        processes.remove(p)
    test_schedule()
    TIME_LOCK.release()

# Function to schedule next test
def test_schedule():
  global test_count
  while len(processes) < max_tests and len(tests_to_run) > 0:
    test = tests_to_run[0]
    test_parts = test.split(':', 1)
    test_set = test_parts[1]
    test_dir = test_parts[0]

    # Build environment
    test_count += 1
    os.makedirs(resdir + '/test-' + str(test_count))
    os.chdir(resdir + '/test-' + str(test_count))
    env = os.environ.copy()
    env['DEJAGNU'] = DEJAGNU
    env['AAP_TIMEOUT'] = str(timeout)
    env['AAP_STACK_SIZE'] = str(stack_size)
    env['AAP_TEXT_SIZE'] = str(text_size)
    # Get a GdbServer
    server = get_next_server()
    servers[server]['running'] = True
    env['AAP_NETPORT'] = server

    # Launch process, store its PID
    p_args = ['runtest', '--tool=gcc',
      '--directory=' + srcdir + '/' + test_dir,
      '--srcdir=' + srcdir,
      '--target_board=' + test_board, test_set]
    print p_args
    FNULL = open(os.devnull, 'w')
    p = subprocess.Popen(p_args, env=env, stdout=FNULL,
                         stderr=subprocess.STDOUT)

    print '(' + str(test_count) + ') ' 'Starting process', test, \
          '( pid:', p.pid, ')', '( server:', server, '),', \
          len(tests_to_run) - 1, 'remaining'
    processes.append({'proc': p, 'server': server, 'test': test,
                      'time': time.time()})
    tests_to_run.remove(test)

# Launch a GdbServer
def launch_gdbserver(port):
  p_args = ['aap-server', '-p', str(int(port))]
  FNULL = open(os.devnull, 'w')
  p = subprocess.Popen(p_args, stdout=FNULL, stderr=subprocess.STDOUT)
  return p

########################
# TEST HANDLING
########################
gcc_tests=['gcc.c-torture:execute.exp=gcc.c-torture/execute/*.c']

# Take a gcc_test spec and convert it into the full set of tests, each as their
# own testspec, adding them to the queue
def glob_tests(testspec):
  test_parts = testspec.split('=', 1)
  test_prefix = test_parts[0]
  test_glob = test_parts[1]
  tests = glob.glob(srcdir + '/' + test_glob)
  # For each test, take the full path back off and build a new testspec
  for t in tests:
    t_name = t[len(srcdir) + 1:]
    tests_to_run.append(test_prefix + '=' + t_name)


########################
# MAIN
########################
def main():
  # Start some gdbservers
  # (If we want to go multimachine, we modify this function)
  i = 0
  while i < max_tests:
    port = rsp_start + i
    p = launch_gdbserver(port)
    servers[':' + str(port)] = {'running': False, 'process': p}
    i += 1

  # Start some tests:
  print 'Storing results in:', resdir
  print 'Counting tests...'
  for test in gcc_tests:
    glob_tests(test)
  print 'There are', len(tests_to_run), ' tests in total'
  TIME_LOCK.acquire()
  test_schedule()
  TIME_LOCK.release()
  signal.signal(signal.SIGCHLD, test_finished)

  # Make sure python doesn't quit until all tests are complete
  while len(processes) > 0 or len(tests_to_run) > 0:
    time.sleep(1)

  # Kill all the gdbservers
  for s in servers.values():
    try:
      s['process'].send_signal(signal.SIGKILL)
    except:
      pass

  # Combine the logs
  logs = glob.glob(resdir + '/test-*/gcc.sum')
  output = open(resdir + '/gcc.sum', 'w')
  p_args = [startdir + '/dg-extract-results.sh'] + logs
  subprocess.Popen(p_args, stdout=output, stderr=subprocess.STDOUT)
  logs = glob.glob(resdir + '/test-*/gcc.log')
  output = open(resdir + '/gcc.log', 'w')
  p_args = [startdir + '/dg-extract-results.sh', '-L'] + logs
  subprocess.Popen(p_args, stdout=output, stderr=subprocess.STDOUT)

# Launch
if __name__ == '__main__':
  main()
EOF
