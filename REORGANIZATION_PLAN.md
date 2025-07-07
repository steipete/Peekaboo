# Peekaboo Repository Reorganization Plan

## Current Structure (Messy)
```
Peekaboo/
├── peekaboo-cli/              # Swift CLI
├── PeekabooCore/              # Shared Swift code
├── PeekabooMac/               # Mac app (nested structure)
│   └── Peekaboo/
│       └── Peekaboo/
├── PeekabooInspector/         # Inspector app (now integrated)
├── AXorcist/                  # AX library
├── src/                       # TypeScript MCP server
├── dist/                      # Build output
├── package.json               # Node.js config
└── ...various config files
```

## Proposed Structure (Clean)
```
Peekaboo/
├── Core/
│   ├── PeekabooCore/          # Shared Swift code (moved from root)
│   └── AXorcist/              # AX library (moved from root)
├── Apps/
│   ├── Mac/                   # Mac app (flattened structure)
│   │   ├── Peekaboo/          # Sources
│   │   ├── PeekabooTests/     # Tests
│   │   └── Package.swift
│   └── CLI/                   # Swift CLI (renamed from peekaboo-cli)
│       ├── Sources/
│       ├── Tests/
│       └── Package.swift
├── Server/                    # MCP TypeScript server
│   ├── src/                   # Source files (moved from root)
│   ├── dist/                  # Build output (moved from root)
│   ├── package.json           # (moved from root)
│   └── tsconfig.json          # (moved from root)
├── Scripts/                   # Build and utility scripts
├── Docs/                      # Documentation
└── Archive/                   # Deprecated projects
    └── PeekabooInspector/     # Standalone inspector (deprecated)
```

## Benefits
1. **Clear separation** between Core libraries, Apps, and Server
2. **Flattened structure** for Mac app (removes double nesting)
3. **Consistent naming** (CLI instead of peekaboo-cli)
4. **Grouped server files** in dedicated directory
5. **Archive folder** for deprecated projects

## Migration Steps
1. Create new directory structure
2. Move Core libraries (PeekabooCore, AXorcist)
3. Flatten and move Mac app
4. Rename and move CLI
5. Move TypeScript server files
6. Update all Package.swift files with new paths
7. Update package.json scripts
8. Test builds for all components