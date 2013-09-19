require 'formula'

class ErlangR16Manuals < Formula
  url 'http://erlang.org/download/otp_doc_man_R16B02.tar.gz'
  sha1 'c64c19d5ab176c8b7c1e05b02b4f2affbed7b0ef'
end

class ErlangR16Htmls < Formula
  url 'http://erlang.org/download/otp_doc_html_R16B02.tar.gz'
  sha1 '142e0b4becc04d3b5bf46a7fa2d48aae43cc84d0'
end

class ErlangR16HeadManuals < Formula
  url 'http://erlang.org/download/otp_doc_man_R16B02.tar.gz'
  sha1 'c64c19d5ab176c8b7c1e05b02b4f2affbed7b0ef'
end

class ErlangR16HeadHtmls < Formula
  url 'http://erlang.org/download/otp_doc_html_R16B02.tar.gz'
  sha1 '142e0b4becc04d3b5bf46a7fa2d48aae43cc84d0'
end

class ErlangR16 < Formula
  homepage 'http://www.erlang.org'
  # Download tarball from GitHub; it is served faster than the official tarball.
  url 'https://github.com/erlang/otp/archive/OTP_R16B02.tar.gz'
  sha1 '81f72efe58a99ab1839eb6294935572137133717'

  # remove the autoreconf if possible
  depends_on :automake
  depends_on :libtool
  depends_on 'unixodbc' if MacOS.version >= :mavericks
  depends_on 'wxmac' => :optional
  depends_on 'fop' => :optional

  fails_with :llvm do
    build 2334
  end

  option 'disable-hipe', "Disable building hipe; fails on various OS X systems"
  option 'halfword', 'Enable halfword emulator (64-bit builds only)'
  option 'time', '`brew test --time` to include a time-consuming test'
  option 'no-docs', 'Do not install documentation'

  def install
    ohai "Compilation takes a long time; use `brew install -v erlang` to see progress" unless ARGV.verbose?

    if ENV.compiler == :llvm
      # Don't use optimizations. Fixes build on Lion/Xcode 4.2
      ENV.remove_from_cflags /-O./
      ENV.append_to_cflags '-O0'
    end
    ENV.append "FOP", "#{HOMEBREW_PREFIX}/bin/fop" if build.with? 'fop'

    # Do this if building from a checkout to generate configure
    system "./otp_build autoconf" if File.exist? "otp_build"

    args = ["--disable-debug",
            "--prefix=#{prefix}",
            "--enable-kernel-poll",
            "--enable-threads",
            "--enable-dynamic-ssl-lib",
            "--enable-shared-zlib",
            "--enable-smp-support"]

    args << "--with-dynamic-trace=dtrace" unless MacOS.version == :leopard or not MacOS::CLT.installed?
    args << "--with-wx-config=#{HOMEBREW_PREFIX}/bin/wx-config" if build.with? 'wxmac'

    unless build.include? 'disable-hipe'
      # HIPE doesn't strike me as that reliable on OS X
      # http://syntatic.wordpress.com/2008/06/12/macports-erlang-bus-error-due-to-mac-os-x-1053-update/
      # http://www.erlang.org/pipermail/erlang-patches/2008-September/000293.html
      args << '--enable-hipe'
    end

    if MacOS.prefer_64_bit?
      args << "--enable-darwin-64bit"
      args << "--enable-halfword-emulator" if build.include? 'halfword' # Does not work with HIPE yet. Added for testing only
    end

    inreplace "./erts/configure", "erl_xcomp_isysroot=\n", "erl_xcomp_isysroot='#{MacOS.sdk_path}'\n" if MacOS.version >= :mavericks
    system "./configure", *args
    system "make"
    ENV.j1 # Install is not thread-safe; can try to create folder twice and fail
    system "make install"

    unless build.include? 'no-docs'
      manuals = build.head? ? ErlangR16HeadManuals : ErlangR16Manuals
      manuals.new.brew {
        man.install Dir['man/*']
        # erl -man expects man pages in lib/erlang/man
        (lib+'erlang').install_symlink man
      }

      htmls = build.head? ? ErlangR16HeadHtmls : ErlangR16Htmls
      htmls.new.brew { doc.install Dir['*'] }
    end
  end

  test do
    `#{bin}/erl -noshell -eval 'crypto:start().' -s init stop`

    # This test takes some time to run, but per bug #120 should finish in
    # "less than 20 minutes". It takes about 20 seconds on a Mac Pro (2009).
    if build.include? "time" && !build.head?
      `#{bin}/dialyzer --build_plt -r #{lib}/erlang/lib/kernel-2.16.3/ebin/`
    end
  end
end
