class Xcodeinstall < Formula
  desc "This is a command-line tool to download and install Apple's Xcode"
  homepage "https://github.com/sebsto/xcodeinstall"
  url "https://github.com/sebsto/xcodeinstall/archive/refs/tags/0.14.1.tar.gz"
  sha256 "3469374f259f27252bf1c1642c8c85f722b7ea6f463d1dbb6519eb480c506eac"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/sebsto/xcodeinstall/releases/download/0.14.1"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "0715c7559e835b7c618a1fb6ac421026307d23665f2147ecfb2e63d0316deb79"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "0715c7559e835b7c618a1fb6ac421026307d23665f2147ecfb2e63d0316deb79"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "0715c7559e835b7c618a1fb6ac421026307d23665f2147ecfb2e63d0316deb79"
    sha256 cellar: :any_skip_relocation, ventura: "0715c7559e835b7c618a1fb6ac421026307d23665f2147ecfb2e63d0316deb79"
    sha256 cellar: :any_skip_relocation, sonoma: "0715c7559e835b7c618a1fb6ac421026307d23665f2147ecfb2e63d0316deb79"
    sha256 cellar: :any_skip_relocation, sequoia: "0715c7559e835b7c618a1fb6ac421026307d23665f2147ecfb2e63d0316deb79"
  end

  def install
    system "swift", "build", "--configuration", "release", "--arch", "arm64", "--arch", "x86_64", "--disable-sandbox"
    bin.install ".build/apple/Products/Release/xcodeinstall"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/xcodeinstall --version").chomp
  end
end
