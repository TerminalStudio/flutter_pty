#include "flutter_pty.h"

#include "include/dart_api_dl.c"

#if _WIN32
#include "flutter_pty_win.c"
#else
#include "flutter_pty_unix.c"
#endif