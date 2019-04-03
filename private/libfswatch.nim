##
##  Copyright (c) 2014-2015 Enrico M. Crisostomo
##                2019 Federico Ceratto
##
##  This program is free software; you can redistribute it and/or modify it under
##  the terms of the GNU General Public License as published by the Free Software
##  Foundation; either version 3, or (at your option) any later version.
##
##  This program is distributed in the hope that it will be useful, but WITHOUT
##  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
##  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
##  details.
##
##  You should have received a copy of the GNU General Public License along with
##  this program.  If not, see <http://www.gnu.org/licenses/>.

const libfswatch_fn* = "libfswatch.so(.11)"

{.pragma: fswatch_import, importc, dynlib: libfswatch_fn.}

##  Status of a library call.
type FSW_STATUS* = cint

##  Opaque type representing a monitoring session.
type
  FSW_SESSION* {.bycopy.} = object


##  Handle to a monitoring session.
type
  FSW_HANDLE* = ptr FSW_SESSION

##
##  Backend-agnostic change flags.
##
##  Each element of this enum represents a backend-agnostic change flag.  No
##  direct mapping to backend-specific change types is guaranteed to exist: a
##  change type may be mapped to multiple `fsw_event_flag` instances included
##  the `PlatformSpecific` flag.
##
##  The values of event flags are all powers of 2, that is numbers @f$f=2^n@f$
##  where @f$n@f$ is an integer.  This representation makes it easy to combine
##  flags into a bit mask and encode multiple events flags into a single integer.
##
##  A monitor implementation is required to map implementation-specific flags
##  into API flags.  Sometimes, though, a perfect match is not possible and the
##  following situation may arise:
##
##    - One platform-specific flag must be mapped into multiple API flags.
##
##    - Multiple platform-specific flags must be mapped into a single API flag.
##
##    - A mapping is not possible for some flags, in which case they should be
##      mapped to fsw_event_flag::PlatformSpecific.  The API currently offers no
##      way to retain a platform-specific event flag value in this case.
##

type
  fsw_event_flag* {.size: sizeof(cint).} = enum
    NoOp = 0,                      # No event has occurred.
    PlatformSpecific = (1 shl 0),  # Platform-specific placeholder for event type that cannot currently be mapped.
    Created = (1 shl 1),           # An object was created.
    Updated = (1 shl 2),           # An object was updated.
    Removed = (1 shl 3),           # An object was removed.
    Renamed = (1 shl 4),           # An object was renamed.
    OwnerModified = (1 shl 5),     # The owner of an object was modified.
    AttributeModified = (1 shl 6), # The attributes of an object were modified.
    MovedFrom = (1 shl 7),         # An object was moved from this location.
    MovedTo = (1 shl 8),           # An object was moved to this location.
    IsFile = (1 shl 9),            # The object is a file.
    IsDir = (1 shl 10),            # The object is a directory.
    IsSymLink = (1 shl 11),        # The object is a symbolic link.
    Link = (1 shl 12),             # The link count of an object has changed.
    Overflow = (1 shl 13)          # The event queue has overflowed.


var FSW_ALL_EVENT_FLAGS* {.importc: "FSW_ALL_EVENT_FLAGS", dynlib: libfswatch_fn.}: array[
    15, fsw_event_flag]

##
##  Get event flag by name.
##
##  This function looks for an event flag called @p name and, if it exists, it
##  writes its value onto @p flag and @c FSW_OK, otherwise @p flag is not
##  modified and @c FSW_ERR_UNKNOWN_VALUE is returned.
##
##  @param[in] name The name of the event flag to look for.
##  @param[out] flag The output variable where the event flag is returned.
##  @return #FSW_OK if the functions succeeds, #FSW_ERR_UNKNOWN_VALUE
##  otherwise.
##

proc fsw_get_event_flag_by_name*(name: cstring; flag: ptr fsw_event_flag): FSW_STATUS {.
    cdecl, importc: "fsw_get_event_flag_by_name", dynlib: libfswatch_fn.}

##  Get the name of an event flag.
##
##  This function looks for the name of the specified event @p flag.  If it
##  exists, it returns its name, otherwise @c nullptr is returned.
##
##  @param[in] flag The event flag to look for.
##  @return The name of @p flag, or @c nullptr if it does not exist.
##

proc fsw_get_event_flag_name*(flag: fsw_event_flag): cstring {.cdecl,
    importc: "fsw_get_event_flag_name", dynlib: libfswatch_fn.}

##  A file change event is represented as an instance of this struct where:
##    - path is the path where the event was triggered.
##    - evt_time the time when the event was triggered.
##    - flags is an array of fsw_event_flag of size flags_num.
##    - flags_num is the size of the flags array.
##

type
  time_t = int
  fsw_cevent* {.bycopy.} = object
    path*: cstring
    evt_time*: time_t
    flags*: ptr fsw_event_flag
    flags_num*: cuint
  ptr_fsw_cevent* = ptr fsw_cevent
  CEventArray* = array[0..0, fsw_cevent]


##  A function pointer of type FSW_CEVENT_CALLBACK is used by the API as a
##  callback to provide information about received events.  The callback is
##  passed the following arguments:
##    - events, a const pointer to an array of events of type const fsw_cevent.
##    - event_num, the size of the events array.
##    - data, optional persisted data for a callback.
##
##  The memory used by the fsw_cevent objects will be freed at the end of the
##  callback invocation.  A callback should copy such data instead of storing
##  a pointer to it.

type FSW_CEVENT_CALLBACK* = proc (events: ptr fsw_cevent; event_num: cuint; data: pointer) {.cdecl.}


##  Event filter type.
type
  fsw_filter_type* = enum
    filter_include, filter_exclude


type
  fsw_cmonitor_filter* {.bycopy.} = object
    text*: cstring
    `type`*: fsw_filter_type
    case_sensitive*: bool
    extended*: bool


##  Event type filter.
type
  fsw_event_type_filter* {.bycopy.} = object
    flag*: fsw_event_flag


##
##  Available monitors.
##
##  This enumeration lists all the available monitors, where the special
##  ::system_default_monitor_type element refers to the platform-specific
##  default monitor.
##

type
  fsw_monitor_type* = enum
    system_default_monitor_type = 0, ## System default monitor.
    fsevents_monitor_type,    ## OS X FSEvents monitor.
    kqueue_monitor_type,      ## BSD `kqueue` monitor.
    inotify_monitor_type,     ## Linux `inotify` monitor.
    windows_monitor_type,     ## Windows monitor.
    poll_monitor_type,        ## `stat()`-based poll monitor.
    fen_monitor_type          ## Solaris/Illumos monitor.


##  Error codes

const
  error_lookup* = [
    "An unknown error has occurred.",
    "The session specified by the handle is unknown.",
    "The session already contains a monitor.",
    "An error occurred while invoking a memory management routine.",
    "The specified monitor type does not exist.",
    "The callback has not been set.",
    "The paths to watch have not been set.",
    "The callback context has not been set.",
    "The path is invalid.",
    "The callback is invalid.",
    "The latency is invalid.",
    "The regular expression is invalid.",
    "A monitor is already running in the specified session.",
    "The value is unknown.",
    "The property is invalid."
  ]

proc log2(v: int): int =
  var x = 1
  while x != v:
    x = x shl 1
    result.inc

proc check_status*(s: FSW_STATUS) =
  if s == 0:
    return
  let msg = error_lookup[log2(s)]
  raise newException(Exception, msg)


##
##  The `libfswatch` C API let users create monitor sessions and receive file
##  system events matching the specified criteria.  Most API functions return
##  a status code of type FSW_STATUS which can take any value specified in
##  the error.h header.  A successful API call returns FSW_OK and the last
##  error can be obtained calling the fsw_last_error() function.
##
##  If the compiler and the C++ library used to build `libfswatch` support the
##  thread_local storage specified then this API is thread safe and a
##  different state is maintained on a per-thread basis.
##
##  Session-modifying API calls (such as fsw_add_path) will take effect the
##  next time a monitor is started with fsw_start_monitor.
##
##  Currently not all monitors supports being stopped, in which case
##  fsw_start_monitor is a non-returning API call.
##
##  A basic session needs at least:
##
##    * A path to watch.
##    * A callback to process the events sent by the monitor.
##
##  as shown in the next example (error checking code was omitted).
##
##      // Use the default monitor.
##      const FSW_HANDLE handle = fsw_init_session(system_default_monitor_type);
##
##      fsw_add_path(handle, "my/path");
##      fsw_set_callback(handle, my_callback);
##
##      fsw_start_monitor(handle);
##
##  A suitable callback function is a function pointer of type
##  FSW_CEVENT_CALLBACK, that is it is a function conforming with the
##  following signature:
##
##      void c_process_events(fsw_cevent const * const events,
##                            const unsigned int event_num,
##                            void * data);
##
##  When a monitor receives change events satisfying all the session criteria,
##  the callback is invoked and passed a copy of the events.
##
##
##  This function initializes the `libfswatch` library and must be invoked
##  before any other calls to the C or C++ API.  If the function succeeds, it
##  returns FSW_OK, otherwise the initialization routine failed and the library
##  should not be usable.
##

proc fsw_init_library*(): FSW_STATUS {.cdecl, importc: "fsw_init_library",
                                    dynlib: libfswatch_fn.}
##
##  This function creates a new monitor session using the specified monitor
##  and returns an handle to it.  This function is the `libfswatch` API entry
##  point.
##
##  @see cmonitor.h for a list of all the available monitors.
##

proc fsw_init_session*(`type`: fsw_monitor_type): FSW_HANDLE {.cdecl,
    importc: "fsw_init_session", dynlib: libfswatch_fn.}
##
##  Adds a path to watch to the specified session.  At least one path must be
##  added to the current session in order for it to be valid.
##

proc fsw_add_path*(handle: FSW_HANDLE; path: cstring): FSW_STATUS {.cdecl,
    importc: "fsw_add_path", dynlib: libfswatch_fn.}
##
##  Adds the specified monitor property.
##

proc fsw_add_property*(handle: FSW_HANDLE; name: cstring; value: cstring): FSW_STATUS {.
    cdecl, importc: "fsw_add_property", dynlib: libfswatch_fn.}
##
##  Sets the allow overflow flag of the monitor.  When this flag is set, a
##  monitor is allowed to overflow and report it as a change event.
##

proc fsw_set_allow_overflow*(handle: FSW_HANDLE; allow_overflow: bool): FSW_STATUS {.
    cdecl, importc: "fsw_set_allow_overflow", dynlib: libfswatch_fn.}
##
##  Sets the callback the monitor invokes when some events are received.  The
##  callback must be set in the current session in order for it to be valid.
##
##  See cevent.h for the definition of FSW_CEVENT_CALLBACK.
##

proc fsw_set_callback*(handle: FSW_HANDLE; callback: FSW_CEVENT_CALLBACK;
                      data: pointer): FSW_STATUS {.cdecl,
    importc: "fsw_set_callback", dynlib: libfswatch_fn.}
##
##  Sets the latency of the monitor.  By default, the latency is set to 1 s.
##

proc fsw_set_latency*(handle: FSW_HANDLE; latency: cdouble): FSW_STATUS {.cdecl,
    importc: "fsw_set_latency", dynlib: libfswatch_fn.}
##
##  Determines whether the monitor recursively scans each watched path or not.
##  Recursive scanning is an optional feature which could not be implemented
##  by all the monitors.  By default, recursive scanning is disabled.
##

proc fsw_set_recursive*(handle: FSW_HANDLE; recursive: bool): FSW_STATUS {.cdecl,
    importc: "fsw_set_recursive", dynlib: libfswatch_fn.}
##
##  Determines whether the monitor only watches a directory when performing a
##  recursive scan.  By default, a monitor accepts all kinds of files.
##

proc fsw_set_directory_only*(handle: FSW_HANDLE; directory_only: bool): FSW_STATUS {.
    cdecl, importc: "fsw_set_directory_only", dynlib: libfswatch_fn.}
##
##  Determines whether a symbolic link is followed or not.  By default, a
##  symbolic link are not followed.
##

proc fsw_set_follow_symlinks*(handle: FSW_HANDLE; follow_symlinks: bool): FSW_STATUS {.
    cdecl, importc: "fsw_set_follow_symlinks", dynlib: libfswatch_fn.}
##
##  Adds an event type filter to the current session.
##
##  See cfilter.h for the definition of fsw_event_type_filter.
##

proc fsw_add_event_type_filter*(handle: FSW_HANDLE;
                               event_type: fsw_event_type_filter): FSW_STATUS {.
    cdecl, importc: "fsw_add_event_type_filter", dynlib: libfswatch_fn.}
##
##  Adds a filter to the current session.  A filter is a regular expression
##  that, depending on whether the filter type is exclusion or not, must or
##  must not be matched for an event path for the event to be accepted.
##
##  See cfilter.h for the definition of fsw_cmonitor_filter.
##

proc fsw_add_filter*(handle: FSW_HANDLE; filter: fsw_cmonitor_filter): FSW_STATUS {.
    cdecl, importc: "fsw_add_filter", dynlib: libfswatch_fn.}
##
##  Starts the monitor if it is properly configured.  Depending on the type of
##  monitor this call might return when a monitor is stopped or not.
##

proc fsw_start_monitor*(handle: FSW_HANDLE): FSW_STATUS {.cdecl,
    importc: "fsw_start_monitor", dynlib: libfswatch_fn.}
##
##  Stops a running monitor.
##

proc fsw_stop_monitor*(handle: FSW_HANDLE): FSW_STATUS {.cdecl,
    importc: "fsw_stop_monitor", dynlib: libfswatch_fn.}
##
##  Checks if a monitor exists and is running.
##

proc fsw_is_running*(handle: FSW_HANDLE): bool {.cdecl, importc: "fsw_is_running",
    dynlib: libfswatch_fn.}
##
##  Destroys an existing session and invalidates its handle.
##

proc fsw_destroy_session*(handle: FSW_HANDLE): FSW_STATUS {.cdecl,
    importc: "fsw_destroy_session", dynlib: libfswatch_fn.}
##
##  Gets the last error code.
##

proc fsw_last_error*(): FSW_STATUS {.cdecl, importc: "fsw_last_error",
                                  dynlib: libfswatch_fn.}
##
##  Check whether the verbose mode is active.
##

proc fsw_is_verbose*(): bool {.cdecl, importc: "fsw_is_verbose", dynlib: libfswatch_fn.}
##
##  Set the verbose mode.
##

proc fsw_set_verbose*(verbose: bool) {.cdecl, importc: "fsw_set_verbose",
                                    dynlib: libfswatch_fn.}


const
  FSW_INVALID_HANDLE* = -1

when defined(HAVE_CXX_THREAD_LOCAL):
  const
    FSW_THREAD_LOCAL* = thread_local
else:
  const
    FSW_THREAD_LOCAL* = true
