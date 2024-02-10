
TARGETS:=all build clean
.PHONY: $(TARGETS)

.DEFAULT_GOAL:=all

all: help

build:
	@mkdir -p bin
	@cd webpass && go build -o ../bin/webpass

clean:
	@rm -rf bin

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       Build webpass"
	@echo "  clean       Clean"
	@echo "  help        Show this help message"
