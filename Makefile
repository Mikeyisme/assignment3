# Compiler settings, allows cross-compilation
CC := $(CROSS_COMPILE)gcc
CFLAGS := -Wall -Werror -g

# Target executable
TARGET := finder-app/writer

# Source and object files
SRC := finder-app/writer.c
OBJ := finder-app/writer.o

# Default target: Build writer
all: $(TARGET)

# Compile the writer application
$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^

# Rule to compile object file
finder-app/writer.o: finder-app/writer.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean target to remove compiled files
clean:
	rm -f $(TARGET) $(OBJ)

