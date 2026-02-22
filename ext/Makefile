CC = cc
CFLAGS = -O2 -fPIC
AR = ar
TARGET = libcocoawebview.a

all: $(TARGET)

$(TARGET): cocoawebview.o
	$(AR) rcs $(TARGET) cocoawebview.o

cocoawebview.o: cocoawebview.c
	$(CC) $(CFLAGS) -c cocoawebview.c

clean:
	rm -f *.o *.a
