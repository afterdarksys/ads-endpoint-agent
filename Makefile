# ADS Endpoint Agent - Makefile Wrapper
# Wraps build.sh for make-based workflows

SHELL := /bin/bash
.PHONY: all clone pull build clean install help

# Default target
all: build

# Clone all repositories
clone:
	@./build.sh clone

# Pull latest changes
pull:
	@./build.sh pull

# Build all components
build:
	@./build.sh build

# Build for specific architectures
build-osxi:
	@./build.sh -a osxi build

build-osxa:
	@./build.sh -a osxa build

build-x86:
	@./build.sh -a x86 build

build-linuxa:
	@./build.sh -a linuxa build

build-win64:
	@./build.sh -a win64 build

# Build specific components
build-darkd:
	@./build.sh -c darkd build

build-scanner:
	@./build.sh -c scanner build

build-clamav:
	@./build.sh -c clamav build

# Clean all artifacts
clean:
	@./build.sh clean

# Install to system
install:
	@./build.sh install

# Show help
help:
	@./build.sh help

# Update and build in one step
update: pull build
