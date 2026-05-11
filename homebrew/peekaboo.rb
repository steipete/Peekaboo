class Peekaboo < Formula
  desc "Lightning-fast macOS screenshots & AI vision analysis"
  homepage "https://github.com/openclaw/Peekaboo"
  url "https://github.com/openclaw/Peekaboo/releases/download/v3.1.2/peekaboo-macos-universal.tar.gz"
  sha256 "6270f07e70dbb57263ea96cc2a5a65540a42fca1c33481b5bcf8357d8e815063"
  license "MIT"
  version "3.1.2"

  # macOS Sequoia (15.0) or later required
  depends_on macos: :sequoia

  def install
    bin.install "peekaboo" => "peekaboo"
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
