
import unittest
from strutils import unindent

import fswatch

  #proc main =
  #  var
  #    disp = newDispatcher()
  #    monitor = newMonitor()
  #    n = 0
  #  n = monitor.add("/tmp")
  #  assert n == 1
  #  n = monitor.add("/tmp", {MonitorAll})
  #  assert n == 1
  #  n = monitor.add("/tmp", {MonitorCloseWrite, MonitorCloseNoWrite})
  #  assert n == 1
  #  n = monitor.add("/tmp", {MonitorMoved, MonitorOpen, MonitorAccess})
  #  assert n == 1
  #  disp.register(monitor,
  #    proc (m: FSMonitor, ev: MonitorEvent) =
  #      echo("Got event: ", ev.kind)
  #      if ev.kind == MonitorMoved:
  #        echo("From ", ev.oldPath, " to ", ev.newPath)
  #        echo("Name is ", ev.name)
  #      else:
  #        echo("Name ", ev.name, " fullname ", ev.fullName))

  #  while true
  #    if not disp.poll(): break
  #

import osproc

import posix, posix_utils

import os

const
  testdir = "testdir"
  testfile = "testdir/testfile"

proc generate_events() =
  const s = 100
  createDir testdir
  writeFile(testfile, "hi")
  sleep s
  writeFile(testfile, "hi")
  sleep s
  writeFile(testfile, "hi")
  sleep s
  removeFile(testfile)

  echo "generator done"

proc terminate(pid: Pid) =
  pid.sendSignal(15)

proc tryTerminate(p: Pid) =
  try:
    terminate(p)
  except:
    discard

proc spawnProcess(target: proc): Pid =
  result = posix.fork()
  if result < 0:
    quit(QuitFailure)
  if result == 0:
    try:
      target()
      quit()
    except:
      echo getCurrentExceptionMsg()
      quit(1)

proc spawnProcess(target: proc(): int): Pid =
  result = posix.fork()
  if result < 0:
    quit(QuitFailure)
  if result == 0:
    try:
      quit(target())
    except:
      echo getCurrentExceptionMsg()
      quit(1)

proc wait(p: Pid): int {.discardable.} =
  ## Wait Pid
  var s: cint
  discard posix.waitpid(p, s, 0)
  return s

const logfn = "tester.log"

import times

when not compileOption("threads") and not defined(async):

  suite "basics":
    test "verbosity":
      check fswatch_is_verbose() == false
      fswatch_enable_verbose()
      check fswatch_is_verbose() == true
      fswatch_disable_verbose()
      check fswatch_is_verbose() == false

    test "init":
      var monitor = newMonitor(latency=0.01)
      assert monitor.isRunning() == false
      monitor.add(testfile)

  suite "sync single-threaded":
    var tester_p: Pid

    setup:
      # At setup time the tester is started

      proc tester() =
        ## Runs in a dedicated thread
        echo "functional test nothreads noasync started"
        var monitor = newMonitor(latency=0.01)
        assert monitor.isRunning() == false
        monitor.add(testfile)

        var data = cstring("")

        proc callback(eg: EventGroup) =
          let f = open(logfn, fmAppend)
          for e in eg:
            f.write($e.kind & "\n")
            echo e.path, " ", $e.kind, " ", e.time.utc()
          f.close()

        monitor.setCallback(callback)

        # blocks here
        monitor.start()

      writeFile(logfn, "")
      tester_p = spawnProcess(tester)

    teardown:
      tryTerminate tester_p

    test "file access":
      # the tester has been already started in `setup`
      generate_events()
      sleep 100 # let tester catch up
      tryTerminate tester_p
      sleep 100 # let tester exit

      let output = readFile(logfn)
      check output == unindent """
        Updated
        PlatformSpecific
        Updated
        Updated
        Updated
        PlatformSpecific
        Updated
        Updated
        AttributeModified
      """


  suite "sync single-threaded filter":
    var tester_p: Pid

    setup:
      # At setup time the tester is started

      proc tester() =
        ## Runs in a dedicated thread
        echo "functional test nothreads noasync started"
        var monitor = newMonitor(latency=0.01)
        assert monitor.isRunning() == false
        monitor.add(testfile)
        monitor.add_event_type_filter(EventKind.AttributeModified)
        monitor.add_event_type_filter(EventKind.Created)

        var data = cstring("")

        proc callback(eg: EventGroup) =
          let f = open(logfn, fmAppend)
          for e in eg:
            f.write($e.kind & "\n")
            echo e.path, " ", $e.kind, " ", e.time.utc()
          f.close()

        monitor.setCallback(callback)

        # blocks here
        monitor.start()

      writeFile(logfn, "")
      tester_p = spawnProcess(tester)

    teardown:
      tryTerminate tester_p

    test "basic":
      # the tester has been already started in `setup`
      generate_events()
      sleep 100 # let tester catch up
      tryTerminate tester_p
      sleep 100 # let tester exit

      let output = readFile(logfn)
      check output == unindent """
        AttributeModified
      """


  suite "sync single-threaded directory recursive ":
    # TODO
    var tester_p: Pid

    proc generate_events_dir() =
      const s = 100
      createDir testdir
      createDir testdir / "nesteddir"

      echo "generator done"

    setup:
      # At setup time the tester is started

      proc tester() =
        ## Runs in a dedicated thread
        echo "functional test nothreads noasync started"
        var monitor = newMonitor(latency=0.01)
        assert monitor.isRunning() == false
        monitor.add(testdir)
        monitor.set_recursive(true)

        var data = cstring("")

        proc callback(eg: EventGroup) =
          let f = open(logfn, fmAppend)
          for e in eg:
            f.write($e.kind & "\n")
            echo e.path, " ", $e.kind, " ", e.time.utc()
          f.close()

        monitor.setCallback(callback)

        # blocks here
        monitor.start()

      writeFile(logfn, "")
      tester_p = spawnProcess(tester)

    teardown:
      tryTerminate tester_p

    test "basic":
      # the tester has been already started in `setup`
      generate_events_dir()
      sleep 100 # let tester catch up
      tryTerminate tester_p
      sleep 100 # let tester exit

      let output = readFile(logfn)
      #FIXME
