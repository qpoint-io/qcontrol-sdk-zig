# qcontrol Zig SDK Guidelines

## Build Commands
- `make deps` - Download Frida devkits
- `make build` - Build the SDK
- `make clean` - Clean build artifacts
- `cd examples && make dev` - Start dev container with tools pre-installed
- `cd examples && make build` - Build example plugins

## Dev Environment
- The examples directory contains a Dockerfile that sets up the full dev environment.
- It includes Zig, qcontrol, and the Claude Code CLI.
- Run `make dev` inside the examples directory to drop into this environment.

## Code Style
- Follow standard Zig formatting (`zig fmt`)
- SDK headers are the source of truth for the ABI
- Use declarative `exportPlugin(.{ ... })` style for plugins
