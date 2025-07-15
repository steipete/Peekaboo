export function generateServerStatusString(version: string): string {
  const aiProviders = process.env.PEEKABOO_AI_PROVIDERS;

  let providersText = "None Configured. Set PEEKABOO_AI_PROVIDERS ENV.";
  if (aiProviders && aiProviders.trim()) {
    const providers = aiProviders
      .split(/[,;]/) // Support both comma and semicolon separators
      .map((p) => p.trim())
      .filter(Boolean);
    providersText = providers.join(", ");
  }

  return `\n\nPeekaboo MCP ${version} using ${providersText}`.trim();
}
