CC = gcc
#CFLAGS = -m64 -Wunused-variable -Wuninitialized
CFLAGS = -m64 
OPTFLAGS = -O3 
MAIN = main.c
DEBUG = debug.c
MEFLIB_DIR = /mnt/local/gdrive/public/pearce/dogs/MEF-lib/lib
SRCFILES = output_u01_channel.c $(MEFLIB_DIR)/mef_lib.c $(MEFLIB_DIR)/AES_encryption.c
TARGET = u01_output 
DTARGET = dbug_mef
INCLUDE = $(MEFLIB_DIR)/include

all: #full build
	$(CC) -o $(TARGET) $(CFLAGS) $(OPTFLAGS) $(MAIN) $(SRCFILES) -I $(INCLUDE) -lm
