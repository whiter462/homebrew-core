class Libepoxy < Formula
  desc "Library for handling OpenGL function pointer management"
  homepage "https://github.com/anholt/libepoxy"
  url "https://download.gnome.org/sources/libepoxy/1.4/libepoxy-1.4.3.tar.xz"
  sha256 "0b808a06c9685a62fca34b680abb8bc7fb2fda074478e329b063c1f872b826f6"

  bottle do
    cellar :any
    sha256 "4a09f9f85ad5a2f0afafc33a22c6f51b4a30a6d885334a2b6c52158482ea7585" => :high_sierra
    sha256 "a96a0e088b6f292422108da73868700ef1a332ebd170695a77e90be7a12a4f86" => :sierra
    sha256 "0ce6f61e0062f6869e47b95363b373502c62cf343ef26bedcf0c4a9819851c79" => :el_capitan
    sha256 "55b56dd68e17a27fa211426ea199084dbdca228a4fc63ddd0d1b3f79ea3c9a1a" => :yosemite
    sha256 "73489728310f2103f6033b46874f6eb5bff90a53b124e06e32e6c430634de8c5" => :x86_64_linux # glibc 2.19
  end

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on :python => :build if MacOS.version <= :snow_leopard
  depends_on "linuxbrew/xorg/mesa" if OS.linux?

  def install
    # see https://github.com/anholt/libepoxy/pull/128
    inreplace "src/meson.build", "version=1", "version 1"
    mkdir "build" do
      system "meson", "--prefix=#{prefix}", *("--libdir=#{lib}" unless OS.mac?), ".."
      system "ninja"
      system "ninja", "test"
      system "ninja", "install"
    end
  end

  test do
    (testpath/"test.c").write <<~EOS

      #include <epoxy/gl.h>
      #ifdef OS_MAC
      #include <OpenGL/CGLContext.h>
      #include <OpenGL/CGLTypes.h>
      #endif
      int main()
      {
          #ifdef OS_MAC
          CGLPixelFormatAttribute attribs[] = {0};
          CGLPixelFormatObj pix;
          int npix;
          CGLContextObj ctx;

          CGLChoosePixelFormat( attribs, &pix, &npix );
          CGLCreateContext(pix, (void*)0, &ctx);
          #endif

          glClear(GL_COLOR_BUFFER_BIT);
          #ifdef OS_MAC
          CGLReleasePixelFormat(pix);
          CGLReleaseContext(pix);
          #endif
          return 0;
      }
    EOS
    args = %w[-lepoxy]
    args += %w[-framework OpenGL -DOS_MAC] if OS.mac?
    args += %w[-o test]
    system ENV.cc, "test.c", *args
    system "ls", "-lh", "test"
    system "file", "test"
    system "./test"
  end
end
