#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { 
  CallToolRequestSchema, 
  ListToolsRequestSchema 
} from '@modelcontextprotocol/sdk/types.js';
import pino from 'pino';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import fs from 'fs/promises';

import { 
  imageToolHandler, 
  imageToolSchema,
  analyzeToolHandler,
  analyzeToolSchema,
  listToolHandler,
  listToolSchema
} from './tools/index.js';
import { generateServerStatusString } from './utils/server-status.js';
import { initializeSwiftCliPath } from './utils/peekaboo-cli.js';

// Get package version and determine package root
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename); // This will be dist/
const packageRootDir = path.resolve(__dirname, '..'); // Moves from dist/ to package root
const packageJsonPath = path.join(packageRootDir, 'package.json');
const packageJson = JSON.parse(await fs.readFile(packageJsonPath, 'utf-8'));
const SERVER_VERSION = packageJson.version;

// Initialize the Swift CLI Path once
initializeSwiftCliPath(packageRootDir);

// Server-level state
let hasSentInitialStatus = false;

// Initialize logger
const baseLogLevel = (process.env.PEEKABOO_LOG_LEVEL || 'info').toLowerCase();
const logFile = process.env.PEEKABOO_LOG_FILE || path.join(os.tmpdir(), 'peekaboo-mcp.log');

const transportTargets = [];

// Always add file transport
transportTargets.push({
  level: baseLogLevel, // Explicitly set level for this transport
  target: 'pino/file',
  options: { 
    destination: logFile,
    mkdir: true // Ensure the directory exists
  }
});

// Conditional console logging for development
if (process.env.PEEKABOO_CONSOLE_LOGGING === 'true') {
  transportTargets.push({
    level: baseLogLevel, // Explicitly set level for this transport
    target: 'pino-pretty',
    options: {
      destination: 2, // stderr
      colorize: true,
      translateTime: 'SYS:standard', // More standard time format
      ignore: 'pid,hostname'
    }
  });
}

const logger = pino({
  name: 'peekaboo-mcp',
  level: baseLogLevel, // Overall minimum level
}, pino.transport({ targets: transportTargets }));

// Tool context for handlers
const toolContext = { logger };

// Convert Zod schema to JSON Schema format
function zodToJsonSchema(schema: any): any {
  // Simple conversion - this would need to be more sophisticated for complex schemas
  if (schema._def?.typeName === 'ZodObject') {
    const properties: any = {};
    const required = [];
    
    for (const [key, value] of Object.entries(schema.shape)) {
      const field = value as any;
      if (field._def?.typeName === 'ZodString') {
        properties[key] = { type: 'string', description: field.description };
        if (!field.isOptional()) required.push(key);
      } else if (field._def?.typeName === 'ZodEnum') {
        properties[key] = { type: 'string', enum: field._def.values, description: field.description };
        if (!field.isOptional()) required.push(key);
      } else if (field._def?.typeName === 'ZodBoolean') {
        properties[key] = { type: 'boolean', description: field.description };
        if (!field.isOptional()) required.push(key);
      } else if (field._def?.typeName === 'ZodOptional') {
        // Handle optional fields
        const innerType = field._def.innerType;
        if (innerType._def?.typeName === 'ZodString') {
          properties[key] = { type: 'string', description: innerType.description };
        } else if (innerType._def?.typeName === 'ZodEnum') {
          properties[key] = { type: 'string', enum: innerType._def.values, description: innerType.description };
        }
      } else if (field._def?.typeName === 'ZodDefault') {
        // Handle default fields
        const innerType = field._def.innerType;
        if (innerType._def?.typeName === 'ZodString') {
          properties[key] = { type: 'string', description: innerType.description, default: field._def.defaultValue() };
        } else if (innerType._def?.typeName === 'ZodEnum') {
          properties[key] = { type: 'string', enum: innerType._def.values, description: innerType.description, default: field._def.defaultValue() };
        } else if (innerType._def?.typeName === 'ZodBoolean') {
          properties[key] = { type: 'boolean', description: innerType.description, default: field._def.defaultValue() };
        }
      } else {
        // Fallback for complex types
        properties[key] = { type: 'object', description: field.description || 'Complex object' };
      }
    }
    
    return {
      type: 'object',
      properties,
      required
    };
  }
  
  // Fallback
  return { type: 'object' };
}

// Create MCP server using the low-level API
const server = new Server(
  {
    name: 'peekaboo-mcp',
    version: SERVER_VERSION
  },
  {
    capabilities: {
      tools: {}
    }
  }
);

// Set up request handlers
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'image',
        description: 'Captures macOS screen content. Targets: entire screen (each display separately), a specific application window, or all windows of an application. Supports foreground/background capture. Captured image(s) can be saved to file(s) and/or returned directly as image data. Window shadows/frames are automatically excluded. Application identification uses intelligent fuzzy matching.',
        inputSchema: zodToJsonSchema(imageToolSchema)
      },
      {
        name: 'analyze',
        description: 'Analyzes an image file using a configured AI model (local Ollama, cloud OpenAI, etc.) and returns a textual analysis/answer. Requires image path. AI provider selection and model defaults are governed by the server\'s `AI_PROVIDERS` environment variable and client overrides.',
        inputSchema: zodToJsonSchema(analyzeToolSchema)
      },
      {
        name: 'list',
        description: 'Lists system items: all running applications, windows of a specific app, or server status. Allows specifying window details. App ID uses fuzzy matching.',
        inputSchema: zodToJsonSchema(listToolSchema)
      }
    ]
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  
  logger.debug({ toolName: name, args }, 'Tool call received');
  
  let response: any; // To store the raw response from tool handlers

  try {
    switch (name) {
      case 'image': {
        const validatedArgs = imageToolSchema.parse(args || {});
        response = await imageToolHandler(validatedArgs, toolContext);
        break;
      }
      case 'analyze': {
        const validatedArgs = analyzeToolSchema.parse(args || {});
        response = await analyzeToolHandler(validatedArgs, toolContext);
        break;
      }
      case 'list': {
        const validatedArgs = listToolSchema.parse(args || {});
        response = await listToolHandler(validatedArgs, toolContext);
        // Do not augment status for peekaboo.list with item_type: "server_status"
        if (validatedArgs.item_type === 'server_status') {
          return response;
        }
        break;
      }
      default:
        response = {
          content: [{ type: 'text', text: `Unknown tool: ${name}` }],
          isError: true
        };
        // Log error for unknown tool, but allow status augmentation if it somehow wasn't an error response initially
        logger.error(`Unknown tool: ${name}`);
    }

    // Augment successful tool responses with initial server status
    if (response && !response.isError && !hasSentInitialStatus) {
      const statusString = generateServerStatusString(SERVER_VERSION);
      const statusContentItem = { type: 'text', text: statusString };

      if (response.content && Array.isArray(response.content) && response.content.length > 0) {
        // Check if first item is a text item
        if (response.content[0].type === 'text') {
          response.content[0].text += statusString; // Append to existing text item
        } else {
          response.content.unshift(statusContentItem); // Prepend as new text item
        }
      } else {
        response.content = [statusContentItem]; // Create content array with status item
      }
      hasSentInitialStatus = true;
      logger.info('Initial server status message appended to tool response.');
    }
    return response; // Return the (potentially augmented) response

  } catch (error) {
    logger.error({ error, toolName: name }, 'Tool execution failed');
    
    // If it's a Zod validation error, return a more helpful message
    if (error && typeof error === 'object' && 'issues' in error) {
      return {
        content: [{
          type: 'text',
          text: `Invalid arguments: ${(error as any).issues.map((issue: any) => issue.message).join(', ')}`
        }],
        isError: true
      };
    }
    
    throw error;
  }
});

async function main() {
  try {
    // Create transport and connect
    const transport = new StdioServerTransport();
    await server.connect(transport);
    
    logger.info('Peekaboo MCP Server started successfully');
    
  } catch (error) {
    logger.error({ error }, 'Failed to start server');
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  try {
    await server.close();
    logger.flush();
  } catch (e) {
    logger.error({error: e}, 'Error during server close on SIGTERM');
  }
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  try {
    await server.close();
    logger.flush();
  } catch (e) {
    logger.error({error: e}, 'Error during server close on SIGINT');
  }
  process.exit(0);
});

main().catch((error) => {
  logger.error({ error }, 'Fatal error in main');
  process.exit(1);
});