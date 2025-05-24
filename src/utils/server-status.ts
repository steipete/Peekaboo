export function generateServerStatusString(version: string): string {
  const aiProviders = process.env.PEEKABOO_AI_PROVIDERS;
  
  let providersText = 'None Configured. Set PEEKABOO_AI_PROVIDERS ENV.';
  if (aiProviders && aiProviders.trim()) {
    const providers = aiProviders.split(',').map(p => p.trim()).filter(Boolean);
    providersText = providers.join(', ');
  }
  
  return `
--- Peekaboo MCP Server Status ---
Name: PeekabooMCP
Version: ${version}
Configured AI Providers (from PEEKABOO_AI_PROVIDERS ENV): ${providersText}
---`.trim();
} 