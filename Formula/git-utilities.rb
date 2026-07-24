# Homebrew formula for git-utilities.
#
# Intended to live in a tap (e.g. bruno-brant/homebrew-tap) so users can:
#
#   brew install bruno-brant/tap/git-utilities
#
# You can also install it straight from this file:
#
#   brew install --formula ./Formula/git-utilities.rb
#
# The `url` / `sha256` below must point at a published release archive. After
# cutting a tag, grab the tarball's sha256 from the release workflow's summary
# (or `shasum -a 256 git-utilities.tar.gz`) and update both fields.
class GitUtilities < Formula
  desc "PowerShell git helper scripts installed as native git subcommands"
  homepage "https://github.com/bruno-brant/git-utilities"
  url "https://github.com/bruno-brant/git-utilities/releases/download/v0.0.0/git-utilities.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"

  # The scripts run on pwsh. On macOS, Homebrew pulls it in via the cask.
  # (Casks are macOS-only; on Linux install pwsh from Microsoft's package repo.)
  depends_on cask: "powershell"

  def install
    scripts = Dir["git-*.ps1"]
    odie "no git-*.ps1 scripts found in the archive" if scripts.empty?

    libexec.install scripts

    Dir[libexec/"git-*.ps1"].each do |script|
      name = File.basename(script, ".ps1")
      (bin/name).write <<~SH
        #!/bin/sh
        exec pwsh -NoProfile -File "#{script}" "$@"
      SH
      chmod 0755, bin/name
    end
  end

  test do
    assert_predicate bin/"git-resolve-all", :exist?
    assert_predicate bin/"git-config-email", :exist?
  end
end
