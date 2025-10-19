class Xcodeinstall < Formula
  desc "This is a command-line tool to download and install Apple's Xcode"
  homepage "https://github.com/sebsto/xcodeinstall"
  url "https://github.com/sebsto/xcodeinstall/archive/refs/tags/v0.14.4.tar.gz"
  sha256 "d8fd8a06b996f0112a7ffb0ae84b45b0493d760203b23984e5bec6794bf92281"
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/sebsto/xcodeinstall/releases/download/v0.14.4"
    sha256 cellar: :any_skip_relocation, arm64_ventura: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, arm64_tahoe: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, ventura: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, sonoma: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, sequoia: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
    sha256 cellar: :any_skip_relocation, tahoe: "19a7fd744e99dccef30c02b19e4d394c72ee5dc14e3527991ce5472b9c5368e3"
  end

  def install
    bin.install "xcodeinstall"
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/xcodeinstall --version").chomp
  end
end
