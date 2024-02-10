
TARGETS:=all run
.PHONY: $(TARGETS)

.DEFAULT_GOAL:=all

all: help

run:
	gpg --export-secret-keys > private-key.gpg
	@cd ../../../ && make build && ./bin/webpass -config docker/testing/example/config.json

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  bootstrap   Bootstrap test environment"
	@echo "  build       Build test environment"
	@echo "  up          Start test environment"
	@echo "  down        Stop test environment"
	@echo "  clean       Clean test environment"
	@echo "  logs        Show test environment logs"
	@echo "  testclient  Connect to testclient container"
	@echo "  help        Show this help message"
