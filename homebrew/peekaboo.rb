class Peekaboo < Formula
  desc "Lightning-fast macOS screenshots & AI vision analysis"
  homepage "https://github.com/openclaw/Peekaboo"
  url "https://github.com/openclaw/Peekaboo/releases/download/v3.0.0/peekaboo-macos-universal.tar.gz"
  sha256 "93aab577b150204faed58d031a376a1c9cf77a2280b346a09241912107b4d5ae"
  license "MIT"
  version "3.0.0"

  # macOS Sequoia (15.0) or later required
  depends_on macos: :sequoia

  def install
    bin.install "peekaboo-macos-universal/peekaboo" => "peekaboo"
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
