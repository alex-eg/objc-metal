all: debug

debug: main.mm
	clang main.mm -o main -framework Foundation -framework Metal -framework MetalKit -framework AppKit -framework QuartzCore -O0 -ggdb

release: main.mm
	clang main.mm -o main -framework Foundation -framework Metal -framework MetalKit -framework AppKit -framework QuartzCore -O2

clean:
	rm -f main

.PHONY: all debug release clean
