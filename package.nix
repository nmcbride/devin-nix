{ pkgs }:

# Reusable builder for a Devin desktop (Electron / VS Code fork) release.
# The tarball is fetched from Devin's update server (commit-pinned URL) and
# unpacked into the store, then run inside an FHS sandbox that supplies the
# Chromium runtime libraries NixOS does not provide under /usr/lib.
#
# Produces a package that exposes:
#   bin/${exe}                       the GUI launcher (e.g. devin-desktop-next)
#   bin/devin                        the local Devin agent (terminal CLI)
#   share/applications/*.desktop     app-menu entry + auth url-handler
#   share/icons + share/pixmaps      icon

{ pname            # derivation / flake-attr name, e.g. "devin-desktop-next"
, version          # upstream version string
, desktopName      # human label in the app menu, e.g. "Devin - Next"
, url              # stable update-server download URL (commit-pinned)
, sha256           # SRI hash of the tarball (== update API sha256hash)
, exe              # GUI executable / launcher command, e.g. devin-desktop-next
, iconFile ? "code.png"   # icon under resources/app/resources/linux/
, urlScheme ? "devin"     # product.json urlProtocol (auth deep-link scheme)
}:

let
  inherit (pkgs)
    lib stdenv buildFHSEnv writeShellScript symlinkJoin
    makeDesktopItem runCommand fetchurl makeWrapper;

  # External tools Devin shells out to (ACP/MCP agents via npx/uvx, python
  # MCP servers, git, make). Shared by BOTH the FHS sandbox (the GUI app)
  # and the agent wrapper (the terminal `devin`) so they behave identically.
  agentTools = with pkgs; [ nodejs uv python3 git gnumake ];

  # The tarball is served from Devin's own auto-update server at a stable,
  # commit-pinned path (the segment in the URL is the build's git commit, not
  # a session token). The website "Download" button hands out a temporary
  # signed redirect, but this update-API URL is permanent and is exactly what
  # the app fetches to update itself, so it is safe to pin here.
  #   https://windsurf-stable.codeium.com/api/update/linux-x64/<quality>/latest
  src = fetchurl { inherit url sha256; };

  # Unpack the tarball (top-level dir is "Devin") into the store unmodified.
  # No ELF patching: the FHS wrapper supplies libraries at runtime instead.
  payload = stdenv.mkDerivation {
    pname = "${pname}-payload";
    inherit version src;

    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    unpackPhase = "tar xzf $src";
    sourceRoot = ".";

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r Devin $out/Devin
      runHook postInstall
    '';
  };

  # FHS sandbox carrying the Electron / Chromium runtime library set.
  fhs = buildFHSEnv {
    name = pname;

    targetPkgs = p: with p; [
      # core
      glibc
      stdenv.cc.cc.lib   # libstdc++ (glibcxx)
      zlib

      # Electron / Chromium runtime
      glib nss nspr atk at-spi2-atk at-spi2-core cups dbus expat
      libdrm libgbm mesa libGL libxkbcommon libsecret libnotify
      alsa-lib systemd pango cairo gdk-pixbuf gtk3 fontconfig freetype

      # X11
      libx11 libxcomposite libxcursor libxdamage
      libxext libxfixes libxi libxrandr libxrender
      libxscrnsaver libxtst libxcb libxkbfile libxshmfence

      which        # PATH probing used during tool discovery
      cacert       # TLS roots so npx/uvx/git can fetch over HTTPS

      # launcher / base shell deps
      coreutils bashInteractive
    ] ++ agentTools;  # node/npx, uv/uvx, python3, git, make (see above)

    runScript = writeShellScript "${exe}-run" ''
      # Make TLS work for tools the app spawns to fetch packages (npx, uvx,
      # git) inside the sandbox, which has no system cert bundle of its own.
      export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      export NIX_SSL_CERT_FILE="$SSL_CERT_FILE"
      export NODE_EXTRA_CA_CERTS="$SSL_CERT_FILE"
      export GIT_SSL_CAINFO="$SSL_CERT_FILE"
      # Launch by absolute path (no cd) so relative args like `${exe} .`
      # resolve against the user's working directory, not the store.
      exec ${payload}/Devin/${exe} --no-sandbox "$@"
    '';
  };

  # The local Devin agent ("Devin Local") — a STATIC binary bundled in the
  # app, so it runs natively on NixOS with no sandbox. The wrapper only
  # injects the spawn tools onto its PATH so terminal MCP/ACP works exactly
  # like the in-GUI agent. Reads the same ~/.config/devin/config.json the IDE
  # writes. Exposed as the `devin` command (distinct from the `${exe}` GUI).
  agent = runCommand "devin-agent-${version}"
    { nativeBuildInputs = [ makeWrapper ]; } ''
    mkdir -p $out/bin
    makeWrapper \
      ${payload}/Devin/resources/app/extensions/windsurf/devin/bin/devin \
      $out/bin/devin \
      --prefix PATH : ${lib.makeBinPath agentTools} \
      --set-default SSL_CERT_FILE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
  '';

  desktopItem = makeDesktopItem {
    name = pname;
    inherit desktopName;
    genericName = "Code Editor";
    comment = "Devin AI software engineer (desktop)";
    exec = "${pname} %U";
    icon = pname;
    categories = [ "Development" "IDE" ];
    startupNotify = true;
    startupWMClass = exe;
  };

  # Separate hidden launcher that claims the auth deep-link scheme
  # (devin://... / devin-next://...). Without this, the browser has nothing
  # to hand the OAuth callback to, so "open in the IDE" silently fails and
  # you fall back to pasting a manual key. Mirrors VS Code's own
  # code-url-handler.desktop. Make it the default with:
  #   xdg-mime default ${pname}-url-handler.desktop x-scheme-handler/${urlScheme}
  urlHandler = makeDesktopItem {
    name = "${pname}-url-handler";
    desktopName = "${desktopName} - URL Handler";
    exec = "${pname} --open-url -- %U";
    icon = pname;
    categories = [ "Development" "IDE" ];
    mimeTypes = [ "x-scheme-handler/${urlScheme}" ];
    noDisplay = true;
    startupNotify = true;
    startupWMClass = exe;
  };

  icon = runCommand "${pname}-icon" { } ''
    mkdir -p $out/share/icons/hicolor/512x512/apps $out/share/pixmaps
    cp ${payload}/Devin/resources/app/resources/linux/${iconFile} \
       $out/share/icons/hicolor/512x512/apps/${pname}.png
    cp ${payload}/Devin/resources/app/resources/linux/${iconFile} \
       $out/share/pixmaps/${pname}.png
  '';
in
symlinkJoin {
  name = "${pname}-${version}";
  # bin/${exe} (GUI, via FHS) + bin/devin (terminal agent) + desktop/icon.
  # Note: both channels' agents provide bin/devin, so enabling stable AND
  # next together collides on `devin` — install one channel's agent.
  paths = [ fhs desktopItem urlHandler icon agent ];

  meta = {
    description = "Devin desktop — ${desktopName} (${version})";
    homepage = "https://devin.ai";
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
    license = lib.licenses.unfree;
  };
}
