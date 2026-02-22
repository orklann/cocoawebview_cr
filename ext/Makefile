CC = cc
CFLAGS = -O2 -fPIC
AR = ar
TARGET = libcocoawebview.a

all: $(TARGET)

$(TARGET): cocoawebview.o
	$(AR) rcs $(TARGET) cocoawebview.o

cocoawebview.o: cocoawebview.m
	$(CC) $(CFLAGS) -c cocoawebview.m

clean:
	rm -f *.o *.a
