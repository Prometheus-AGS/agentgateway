# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AgentGateway is an open-source data plane for agentic AI connectivity, written in Rust. It provides drop-in security, observability, and governance for agent-to-agent and agent-to-tool communication, supporting protocols like Agent2Agent (A2A) and Model Context Protocol (MCP).

## Development Commands

### Core Development
```bash
# Build the project
make build

# Run lint checks
make lint

# Fix lint issues automatically
make fix-lint

# Run tests
make test

# Clean build artifacts
cargo clean
```

### UI Development
```bash
cd ui
npm install      # Install dependencies
npm run dev      # Start development server with turbopack
npm run build    # Build for production
npm run lint     # Run linting
npm test         # Run tests
```

### Code Generation
```bash
make gen                    # Generate APIs and schema, then fix lint
make generate-apis          # Generate xDS APIs from protobuf
make generate-schema        # Generate JSON schemas
```

### Docker and Validation
```bash
make docker                 # Build Docker image
make validate              # Validate all example configurations
make run-validation-deps   # Start validation dependencies
make stop-validation-deps  # Stop validation dependencies
```

### Single Test Execution
```bash
# Run specific test
cargo test <test_name>

# Run tests in specific crate
cargo test -p agentgateway

# Run with output
cargo test -- --nocapture
```

## Architecture Overview

### Configuration System (Triple-Tier)
AgentGateway has three distinct configuration layers:

1. **Static Configuration**: Set once at startup via environment variables or YAML/JSON files. Contains global settings like logging, ports, and process lifecycle settings.

2. **Local Configuration**: File-based (YAML/JSON) configuration with hot-reload capability via file watch. Defines the full feature set including backends, routes, and policies.

3. **XDS Configuration**: Remote control plane configuration using XDS Transport Protocol with custom protobuf types (not Envoy types). Optimized for efficiency and minimal configuration fanout.

All three layers translate to a shared Internal Representation (IR) used by the proxy at runtime.

### Crate Structure
The project uses a modular Rust workspace architecture:

- `crates/agentgateway`: Main gateway implementation and CLI
- `crates/agentgateway-app`: Application layer
- `crates/core`: Core functionality shared across crates
- `crates/xds`: XDS protocol implementation
- `crates/hbone`: HTTP tunneling over TCP
- `crates/a2a-sdk`: Agent-to-Agent SDK
- `crates/celx`: CEL expression evaluation
- `crates/xtask`: Build automation tasks

### Technology Stack
- **Core**: Rust 1.90+ with Tokio async runtime
- **UI**: Next.js 15 with React 19, Radix UI components, Tailwind CSS
- **Protocols**: HTTP/1.1, HTTP/2, gRPC, MCP, A2A
- **Configuration**: XDS, YAML, JSON
- **Build**: Cargo workspace with custom xtasks
- **Deployment**: Docker, Kubernetes (via Helm charts)

### Key Design Principles
- **Performance-First**: Direct mapping between user APIs and internal representation to minimize configuration fanout
- **Efficient Configuration**: Resources point to parents rather than parents containing child lists, reducing update overhead
- **Runtime Policy Merging**: Policies are sent as-is with references, merging happens at runtime rather than control plane
- **Modular Architecture**: Clean separation of concerns across crates

### Configuration File Structure
Examples are provided in `examples/*/config.yaml` covering:
- Basic configuration (`examples/basic/`)
- A2A protocol setup (`examples/a2a/`)
- MCP authentication (`examples/mcp-authentication/`)
- OpenAPI integration (`examples/openapi/`)
- TLS configuration (`examples/tls/`)
- Authorization and RBAC (`examples/authorization/`)

### Running Examples
```bash
# Run with specific example configuration
cargo run -- -f examples/basic/config.yaml

# Validate configuration only
cargo run -- -f examples/basic/config.yaml --validate-only
```

### UI Access
After starting the gateway, the web UI is available at `http://localhost:15000/ui`

### Development Environment
The project supports GitHub Codespaces for quick setup. For local development:
- Requires Rust 1.86+ and npm 10+
- Set `CARGO_NET_GIT_FETCH_WITH_CLI=true` for git dependencies
- Use `make build` instead of `cargo build` for the full build process

### Protocol Support
- **MCP (Model Context Protocol)**: Full client/server support with authentication
- **A2A (Agent2Agent)**: Native protocol implementation via a2a-sdk
- **OpenAPI**: Legacy API transformation into MCP resources
- **gRPC**: Protocol buffers with Tonic framework
- **WebSockets**: For real-time communication

### Testing Strategy
- Unit tests: `cargo test` in individual crates
- Integration tests: Full end-to-end scenarios in examples
- UI tests: Jest/React testing in ui/ directory
- Configuration validation: `make validate` runs all example configs