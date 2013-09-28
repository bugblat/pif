UNIFLAGS	= -Wall -g -fPIC -I. -DBUILDING_LIBPIF -fvisibility=hidden
CXX				= g++
CXXFLAGS	= -ansi $(UNIFLAGS) -fvisibility-inlines-hidden
CC				= gcc
CCFLAGS		= $(UNIFLAGS)

DEPS			= pif.h pifwrap.h lowlevel.h bcm2835.h llbufs.h
OBJS			= pif.o pifwrap.o lowlevel.o bcm2835.o
TARGET		= libpif.so
LIBS			= -lstdc++
LDFLAGS		= -shared -Wl,-soname,$(TARGET) -fvisibility=hidden




%.o : %.cpp $(DEPS)
	$(CXX) -c -o $@ $(CXXFLAGS) $<

%.o : %.c $(DEPS)
	$(CC) -c -o $@ $(CCFLAGS) $<

$(TARGET): $(OBJS)
	$(CXX) -o $@ $(OBJS) $(LDFLAGS)



install:
	cp $(TARGET) /usr/lib
	chmod 0755 /usr/lib/$(TARGET)



.PHONY: clean

clean:
	rm -f *.o $(TARGET)
