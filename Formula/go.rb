class Go < Formula
  desc "Open source programming language to build simple/reliable/efficient software"
  homepage "https://golang.org"

  stable do
    url "https://storage.googleapis.com/golang/go1.9.1.src.tar.gz"
    mirror "https://fossies.org/linux/misc/go1.9.1.src.tar.gz"
    version "1.9.1"
    sha256 "a84afc9dc7d64fe0fa84d4d735e2ece23831a22117b50dafc75c1484f1cb550e"

    go_version = version.to_s.split(".")[0..1].join(".")
    resource "gotools" do
      url "https://go.googlesource.com/tools.git",
          :branch => "release-branch.go#{go_version}"
    end
  end

  bottle do
    sha256 "6e414b95839b7bd8b4c6b7c54671afa0ee90f2889fc2a745371335d32b58fbc9" => :high_sierra
    sha256 "81d491f83885c6f8a323d9a327c4980a58b5814c5596f3503e0ead2bbfce7c55" => :sierra
    sha256 "13399759706125f07d1ce1e61430870aa9ff3f314d52edd36c0d7ff9f14cbcdf" => :el_capitan
    sha256 "d26edbdf36971f6cc2268a5b2df2724e120de46860474336bc241e4e3de86854" => :x86_64_linux
  end

  head do
    url "https://go.googlesource.com/go.git"

    resource "gotools" do
      url "https://go.googlesource.com/tools.git"
    end
  end

  option "without-cgo", "Build without cgo (also disables race detector)"
  option "without-race", "Build without race detector"

  depends_on :macos => :mountain_lion

  # Don't update this unless this version cannot bootstrap the new version.
  resource "gobootstrap" do
    if OS.mac?
      url "https://storage.googleapis.com/golang/go1.7.darwin-amd64.tar.gz"
      sha256 "51d905e0b43b3d0ed41aaf23e19001ab4bc3f96c3ca134b48f7892485fc52961"
    elsif OS.linux?
      url "https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz"
      sha256 "702ad90f705365227e902b42d91dd1a40e48ca7f67a2f4b2fd052aaa4295cd95"
    end
    version "1.7"
  end

  def install
    # Fixes: Error: Failure while executing: ../bin/ldd ../line-clang.elf: Permission denied
    unless OS.mac?
      chmod "+x", Dir.glob("src/debug/dwarf/testdata/*.elf")
      chmod "+x", Dir.glob("src/debug/elf/testdata/*-exec")
    end

    (buildpath/"gobootstrap").install resource("gobootstrap")
    ENV["GOROOT_BOOTSTRAP"] = buildpath/"gobootstrap"

    cd "src" do
      ENV["GOROOT_FINAL"] = libexec
      ENV["GOOS"]         = OS::NAME

      ENV["CGO_ENABLED"]  = "0" if build.without?("cgo")
      system "./make.bash", "--no-clean"
    end

    (buildpath/"pkg/obj").rmtree
    rm_rf "gobootstrap" # Bootstrap not required beyond compile.
    libexec.install Dir["*"]
    bin.install_symlink Dir[libexec/"bin/go*"]

    # Race detector only supported on amd64 platforms.
    # https://golang.org/doc/articles/race_detector.html
    if build.with?("cgo") && build.with?("race") && MacOS.prefer_64_bit?
      system bin/"go", "install", "-race", "std"
    end

    # Build and install godoc
    ENV.prepend_path "PATH", bin
    ENV["GOPATH"] = buildpath
    (buildpath/"src/golang.org/x/tools").install resource("gotools")
    cd "src/golang.org/x/tools/cmd/godoc/" do
      system "go", "build"
      (libexec/"bin").install "godoc"
    end
    bin.install_symlink libexec/"bin/godoc"
  end

  def caveats; <<~EOS
    A valid GOPATH is required to use the `go get` command.
    If $GOPATH is not specified, $HOME/go will be used by default:
      https://golang.org/doc/code.html#GOPATH

    You may wish to add the GOROOT-based install location to your PATH:
      export PATH=$PATH:#{opt_libexec}/bin
    EOS
  end

  test do
    (testpath/"hello.go").write <<~EOS
      package main

      import "fmt"

      func main() {
          fmt.Println("Hello World")
      }
    EOS
    # Run go fmt check for no errors then run the program.
    # This is a a bare minimum of go working as it uses fmt, build, and run.
    system bin/"go", "fmt", "hello.go"
    assert_equal "Hello World\n", shell_output("#{bin}/go run hello.go")

    # godoc was installed
    assert_predicate libexec/"bin/godoc", :exist?
    assert_predicate libexec/"bin/godoc", :executable?

    if build.with? "cgo"
      ENV["GOOS"] = "freebsd"
      system bin/"go", "build", "hello.go"
    end
  end
end
