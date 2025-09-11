HIPCC = hipcc
CXX = g++

TARGET = softmax
TARGET_SERIAL = softmax_serial

SRCS = main.cpp kernel.hip
SRCS_SERIAL = main_serial.cpp

HEADERS = main.h
HEADERS_SERIAL = main_serial.h

CXXFLAGS = -O2 -ffast-math

all: $(TARGET) $(TARGET_SERIAL)

$(TARGET): $(SRCS) $(HEADERS)
	$(HIPCC) $(CXXFLAGS) $(SRCS) -o $(TARGET)

$(TARGET_SERIAL): $(SRCS_SERIAL) $(HEADERS_SERIAL)
	$(CXX) $(CXXFLAGS) $(SRCS_SERIAL) -o $(TARGET_SERIAL) -lm

clean:
	rm -f $(TARGET) $(TARGET_SERIAL) *.o
