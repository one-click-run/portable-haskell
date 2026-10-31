#include <errno.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <windows.h>

#define BUFFER_SIZE 32768

static int join_path(wchar_t *out, size_t out_count, const wchar_t *root, const wchar_t *suffix) {
    return _snwprintf_s(out, out_count, _TRUNCATE, L"%ls\\%ls", root, suffix) >= 0;
}

static void set_root_variable(const wchar_t *name, const wchar_t *root, const wchar_t *suffix) {
    wchar_t value[BUFFER_SIZE];
    if (!join_path(value, BUFFER_SIZE, root, suffix) || !SetEnvironmentVariableW(name, value)) {
        fwprintf(stderr, L"Unable to set %ls.\n", name);
        ExitProcess(2);
    }
}

int wmain(int argc, wchar_t **argv) {
    wchar_t root[BUFFER_SIZE];
    DWORD length = GetModuleFileNameW(NULL, root, BUFFER_SIZE);
    if (length == 0 || length >= BUFFER_SIZE) {
        fwprintf(stderr, L"Unable to locate the portable Haskell directory.\n");
        return 2;
    }
    wchar_t *separator = wcsrchr(root, L'\\');
    if (separator == NULL) {
        fwprintf(stderr, L"Invalid launcher path.\n");
        return 2;
    }
    *separator = L'\0';

    set_root_variable(L"CABAL_DIR", root, L"data\\cabal");
    set_root_variable(L"STACK_ROOT", root, L"data\\stack");
    SetEnvironmentVariableW(L"GHCUP_USE_XDG_DIRS", L"1");
    set_root_variable(L"XDG_CACHE_HOME", root, L"data\\xdg-cache");
    set_root_variable(L"XDG_CONFIG_HOME", root, L"data\\xdg-config");
    set_root_variable(L"XDG_DATA_HOME", root, L"data\\xdg-data");
    set_root_variable(L"XDG_STATE_HOME", root, L"data\\xdg-state");
    SetEnvironmentVariableW(L"ONE_CLICK_RUN_OFFLINE_RUNTIME", L"1");

    wchar_t old_path[BUFFER_SIZE];
    DWORD old_length = GetEnvironmentVariableW(L"PATH", old_path, BUFFER_SIZE);
    if (old_length >= BUFFER_SIZE) {
        fwprintf(stderr, L"PATH is too long.\n");
        return 2;
    }
    if (old_length == 0) old_path[0] = L'\0';

    wchar_t portable_path[BUFFER_SIZE];
    int written = _snwprintf_s(
        portable_path,
        BUFFER_SIZE,
        _TRUNCATE,
        L"%ls\\ghc\\bin;%ls\\ghc\\mingw\\bin;%ls\\cabal;%ls\\hls;%ls\\stack;%ls",
        root, root, root, root, root, old_path
    );
    if (written < 0 || !SetEnvironmentVariableW(L"PATH", portable_path)) {
        fwprintf(stderr, L"Unable to configure the portable PATH.\n");
        return 2;
    }

    wchar_t server[BUFFER_SIZE];
    if (!join_path(server, BUFFER_SIZE, root, L"hls\\haskell-language-server-wrapper.exe")) {
        fwprintf(stderr, L"HLS path is too long.\n");
        return 2;
    }
    if (GetFileAttributesW(server) == INVALID_FILE_ATTRIBUTES) {
        fwprintf(stderr, L"Bundled Haskell Language Server is missing: %ls\n", server);
        return 2;
    }

    const wchar_t **child_argv = calloc((size_t)argc + 1, sizeof(wchar_t *));
    if (child_argv == NULL) {
        fwprintf(stderr, L"Unable to allocate launcher arguments.\n");
        return 2;
    }
    child_argv[0] = server;
    for (int index = 1; index < argc; ++index) child_argv[index] = argv[index];
    child_argv[argc] = NULL;

    intptr_t result = _wspawnv(_P_WAIT, server, child_argv);
    free(child_argv);
    if (result == -1) {
        fwprintf(stderr, L"Unable to start HLS (errno %d).\n", errno);
        return 2;
    }
    return (int)result;
}
