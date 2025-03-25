#include <stdio.h>
#include <stdlib.h>
#include <syslog.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

int main(int argc, char *argv[]) {
    // Open syslog for logging
    openlog("writer", LOG_PID | LOG_CONS, LOG_USER);

    // Check if correct number of arguments is provided
    if (argc != 3) {
        syslog(LOG_ERR, "Usage: %s <file_path> <string_to_write>", argv[0]);
        fprintf(stderr, "Error: Incorrect number of arguments.\n");
        closelog();
        return 1;
    }

    const char *file_path = argv[1];
    const char *write_str = argv[2];

    // Open the file with write permissions, create if it doesn't exist, truncate if it does
    int fd = open(file_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        syslog(LOG_ERR, "Error opening file %s: %s", file_path, strerror(errno));
        fprintf(stderr, "Error: Could not open file %s.\n", file_path);
        closelog();
        return 1;
    }

    // Write the string to the file
    ssize_t bytes_written = write(fd, write_str, strlen(write_str));
    if (bytes_written == -1) {
        syslog(LOG_ERR, "Error writing to file %s: %s", file_path, strerror(errno));
        fprintf(stderr, "Error: Failed to write to file %s.\n", file_path);
        close(fd);
        closelog();
        return 1;
    }

    // Log the success message
    syslog(LOG_DEBUG, "Writing '%s' to '%s'", write_str, file_path);

    // Close file and syslog
    close(fd);
    closelog();

    return 0;
}

