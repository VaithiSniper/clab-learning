CXX := g++
CXXFLAGS := -std=c++17 -Wall -Wextra -Wpedantic -g

BIN := lru_cache

SRC_FILES := $(wildcard *.cpp)
OBJ_FILES := $(SRC_FILES:.cpp=.o)

.PHONY: all build clean

all: build

build: $(BIN)

$(BIN): $(OBJ_FILES)
	$(CXX) $(CXXFLAGS) -o $@ $^

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ_FILES) $(BIN)
