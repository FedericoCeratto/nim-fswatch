##
## Libfswatch wrapper
##
## Copyright (c) 2019 Federico Ceratto <federico.ceratto@gmail.com>
## Released under GPLv3 license

import
  os,
  strutils,
  tables,
  times

import fswatch/private/libfswatch

export fsw_set_callback # used by the setCallback template

type
  FSWCeventPtr* = ptr fsw_cevent
  FSMonitor* = object of RootObj
    session*: FSW_HANDLE

  EventGroup* = object
    ptr_events: FSWCeventPtr
    event_num: cuint

  Event* = object
    path*: string
    time*: Time
    kind*: fsw_event_flag

type EventKind* = fsw_event_flag

proc newMonitor*(latency: float64 = 0.1): FSMonitor =
  ## Creates a new file system monitor.
  doAssert fsw_init_library() == 0
  result.session = fsw_init_session(system_default_monitor_type)
  check_status result.session.fsw_set_latency(latency)


proc add*(monitor: FSMonitor, target: string) =
  ## Adds ``target`` which may be a directory or a file to the list of
  ## watched paths of ``monitor``.
  check_status monitor.session.fsw_add_path(target)

proc isRunning*(m: FSMonitor): bool =
  ## Returns true if the monitor is running
  m.session.fsw_is_running()

proc start*(monitor: FSMonitor) =
  ## Start monitor
  check_status monitor.session.fsw_start_monitor()

proc stop*(monitor: FSMonitor) =
  ## Stop monitor
  check_status monitor.session.fsw_stop_monitor()

proc fswatch_enable_verbose*() =
  ## Enable verbose mode
  fsw_set_verbose(true)

proc fswatch_disable_verbose*() =
  ## Enable verbose mode
  fsw_set_verbose(false)

proc fswatch_is_verbose*(): bool =
  ## Check Enable verbose mode
  fsw_is_verbose()

proc add_event_type_filter*(m: FSMonitor, eks: EventKind) =
  ## Add filtering by event time. Multiple type filters can be added.
  let f = fsw_event_type_filter(flag: eks)
  check_status m.session.fsw_add_event_type_filter(f)

proc set_recursive*(m: FSMonitor, recursive: bool) =
  ## Set recursive scanning on each watched path
  check_status m.session.fsw_set_recursive(recursive)

proc set_directory_only*(m: FSMonitor, directory_only: bool) =
  ## Set scanning for directories only
  check_status m.session.fsw_set_directory_only(directory_only)

template asarray[T](p:pointer):auto =
  type A = array[0..100,T]
  cast[ptr A](p)

iterator iter_events(ptr_events: FSWCeventPtr, cnt: cuint): fsw_cevent =
  var events = asarray[fsw_cevent](ptr_events)
  for i in 0..(cnt-1):
    yield  events[i]

iterator iter_flags(ptr_flags: ptr EventKind, cnt: cuint): EventKind =
  let flags = asarray[fsw_event_flag](ptr_flags)
  for i in 0..(cnt-1):
    yield flags[i]

iterator items*(eg: EventGroup): Event =
  ## Iterate events in an EventGroup
  for e in iter_events(eg.ptr_events, eg.event_num):
    for f in iter_flags(e.flags, e.flags_num):
      let path: string = $e.path
      let t = times.fromUnix(e.evt_time.int64)
      yield Event(path: path, time:t, kind:f)

template setCallback*(monitor: FSMonitor,
    callback: proc(eg: EventGroup)
  ): untyped =
  proc innercallback(ptr_events: FSWCeventPtr, event_num: cuint, data: pointer) {.cdecl.} =
    let eg = EventGroup(ptr_events:ptr_events, event_num:event_num)
    callback(eg)
  check_status monitor.session.fsw_set_callback(innercallback, addr data)
