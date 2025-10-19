class Xcodeinstall < Formula
  desc "This is a command-line tool to download and install Apple's Xcode"
  homepage "https://github.com/sebsto/xcodeinstall"
  url "https://github.com/sebsto/xcodeinstall/archive/refs/tags/v0.14.2.tar.gz"
  sha256 "e085132fc3edd2f413c9aab645d9d03d14accd4e71ecb828d274f07b3a862041"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/sebsto/xcodeinstall/releases/download/v0.14.2"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "d3fe108f55ebadd843a7ffc4e45f52cf916014d7f57aeddcfea6058783e425ac"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "d3fe108f55ebadd843a7ffc4e45f52cf916014d7f57aeddcfea6058783e425ac"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "d3fe108f55ebadd843a7ffc4e45f52cf916014d7f57aeddcfea6058783e425ac"
    sha256 cellar: :any_skip_relocation, ventura: "d3fe108f55ebadd843a7ffc4e45f52cf916014d7f57aeddcfea6058783e425ac"
    sha256 cellar: :any_skip_relocation, sonoma: "d3fe108f55ebadd843a7ffc4e45f52cf916014d7f57aeddcfea6058783e425ac"
    sha256 cellar: :any_skip_relocation, sequoia: "d3fe108f55ebadd843a7ffc4e45f52cf916014d7f57aeddcfea6058783e425ac"
  end

  def install
    bin.install "xcodeinstall"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/xcodeinstall --version").chomp
  end
end
