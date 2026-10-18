#include <stdio.h>
#include <unistd.h>

#ifndef PLUGIN_SERVER_PATH
#error PLUGIN_SERVER_PATH is required
#endif

// CodeQL's Intel extractor must launch Xcode 27's ARM-only macro host natively.
int main(int argc, char **argv) {
    char *arguments[argc + 3];
    arguments[0] = "/usr/bin/arch";
    arguments[1] = "-arm64";
    arguments[2] = PLUGIN_SERVER_PATH;
    for (int i = 1; i < argc; ++i) {
        arguments[i + 2] = argv[i];
    }
    arguments[argc + 2] = NULL;
    execv(arguments[0], arguments);
    perror("native Swift plugin server");
    return 71;
}
