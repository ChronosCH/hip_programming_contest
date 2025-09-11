HIPCC = hipcc
CXX = g++

TARGET = prefix_sum
TARGET_SERIAL = prefix_sum_serial

SRCS = main.cpp kernel.hip
SRCS_SERIAL = main_serial.cpp

HEADERS = main.h

HIPFLAGS = -O3 --amdgpu-target=gfx908 -DNDEBUG -mllvm -amdgpu-early-inline-all=true
CXXFLAGS = -O3 -DNDEBUG

all: $(TARGET) $(TARGET_SERIAL)

$(TARGET): $(SRCS) $(HEADERS)
	$(HIPCC) $(HIPFLAGS) $(SRCS) -o $(TARGET)

$(TARGET_SERIAL): $(SRCS_SERIAL)
	$(CXX) $(CXXFLAGS) $(SRCS_SERIAL) -o $(TARGET_SERIAL)

clean:
	rm -f $(TARGET) $(TARGET_SERIAL) *.o
