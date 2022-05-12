#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#include <termios.h>
#include <util.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#include "include/dart_api.h"
#include "include/dart_api_dl.h"
#include "include/dart_native_api.h"

typedef struct PtyOptions
{
    int rows;

    int cols;

    char *executable;

    char **arguments;

    char **environment;

    char *working_directory;

    Dart_Port stdout_port;

    Dart_Port exit_port;

} PtyOptions;

typedef struct PtyHandle
{
    int ptm;

    int pid;

} PtyHandle;

typedef struct ReadThreadOptions
{
    int fd;

    Dart_Port port;

} ReadThreadOptions;

void read_loop(ReadThreadOptions *options)
{
    char buffer[1024];

    while (1)
    {
        ssize_t n = read(options->fd, buffer, sizeof(buffer));

        if (n < 0)
        {
            // TODO: handle error
            break;
        }

        if (n == 0)
        {
            break;
        }

        Dart_CObject result;
        result.type = Dart_CObject_kTypedData;
        result.value.as_typed_data.type = Dart_TypedData_kUint8;
        result.value.as_typed_data.length = n;
        result.value.as_typed_data.values = (uint8_t *)buffer;

        Dart_PostCObject_DL(options->port, &result);
    }
}

void start_read_thread(int fd, Dart_Port port)
{

    ReadThreadOptions *options = malloc(sizeof(ReadThreadOptions));

    options->fd = fd;

    options->port = port;

    pthread_t _thread;

    pthread_create(&_thread, NULL, &read_loop, options);
}

PtyHandle *pty_create(PtyOptions *options)
{
    struct winsize ws;

    ws.ws_row = options->rows;
    ws.ws_col = options->cols;

    int ptm;

    int pid = forkpty(&ptm, NULL, NULL, &ws);

    if (pid < 0)
    {
        // TODO: handle error
        return NULL;
    }

    if (pid == 0)
    {
        int ok = execvp(options->executable, options->arguments);

        if (ok < 0)
        {
            perror("execvp");
        }
    }

    setsid();

    PtyHandle *handle = (PtyHandle *)malloc(sizeof(PtyHandle));

    handle->ptm = ptm;
    handle->pid = pid;

    start_read_thread(ptm, options->stdout_port);

    return handle;
}

void pty_write(PtyHandle *handle, char *buffer, int length)
{
    write(handle->ptm, buffer, length);
}