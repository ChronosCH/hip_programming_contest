HIPCC = hipcc
CXX = g++

TARGET = main
TARGET_SERIAL = main_serial

SRCS = main.cpp
SRCS_SERIAL = main_serial.cpp

HEADERS = main.h
HEADERS_SERIAL = main_serial.h

CXXFLAGS = -O3 -ffast-math -march=native
HIPFLAGS = -O3 --offload-arch=gfx908 -ffast-math

all: $(TARGET) $(TARGET_SERIAL)

$(TARGET): $(SRCS) $(HEADERS)
	$(HIPCC) $(HIPFLAGS) $(SRCS) -o $(TARGET)

$(TARGET_SERIAL): $(SRCS_SERIAL) $(HEADERS_SERIAL)
	$(CXX) $(CXXFLAGS) $(SRCS_SERIAL) -o $(TARGET_SERIAL)

clean:
	rm -f $(TARGET) $(TARGET_SERIAL) *.o