class Peekaboo < Formula
  desc "Lightning-fast macOS screenshots & AI vision analysis"
  homepage "https://github.com/steipete/peekaboo"
  url "https://github.com/steipete/peekaboo/releases/download/v3.0.0-beta2/peekaboo-macos-arm64.tar.gz"
  sha256 "ae5d5dc5dc8b881cdc1519309c177a545071291821333c9ecdd144cdb7190b28"
  license "MIT"
  version "3.0.0-beta2"

  # macOS Sonoma (14.0) or later required
  depends_on macos: :sonoma

  def install
    odie "Peekaboo is Apple Silicon only (arm64)." if Hardware::CPU.intel?
    bin.install "peekaboo-macos-arm64/peekaboo" => "peekaboo"
  end

  def post_install
    # Ensure the binary is executable
    chmod 0755, "#{bin}/peekaboo"
  end

  def caveats
    <<~EOS
      Peekaboo requires Screen Recording permission to capture screenshots.
      
      To grant permission:
      1. Open System Settings > Privacy & Security > Screen & System Audio Recording
      2. Enable access for your Terminal application
      
      For AI analysis features, configure your AI providers:
        export PEEKABOO_AI_PROVIDERS="openai/gpt-5.1,anthropic/claude-sonnet-4.5"
        export OPENAI_API_KEY="your-api-key"
      
      Or create a config file:
        peekaboo config init
    EOS
  end

  test do
    require "json"
    # Test that the binary runs and returns version
    assert_match "Peekaboo", shell_output("#{bin}/peekaboo --version")
    
    # Test help command
    assert_match "USAGE:", shell_output("#{bin}/peekaboo --help")
  end
end
