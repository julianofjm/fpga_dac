CXX = g++

OUT = dds_application
CFLAGS = -Wall -Wextra
LDFLAGS = -lserial

all: $(OUT)

dds_application: dds_application.o dds_application.h
	$(CXX) $(CFLAGS) $< -o $@ $(LDFLAGS)

%.o : %.cpp
	$(CXX) $(CFLAGS) -c $*.cpp -o $@
