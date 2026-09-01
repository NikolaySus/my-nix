{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  adwaita-icon-theme,
}:
rustPlatform.buildRustPackage rec {
  pname = "yufi";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "AtefR";
    repo = "YuFi";
    rev = "v${version}";
    hash = "sha256-WnadJ7gekAZUOe64s271tD6iNTT2U18XdRfJaqbQZCU=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = [
    adwaita-icon-theme
    gtk4
  ];

  postInstall = ''
    install -Dm644 packaging/com.yufi.app.desktop \
      "$out/share/applications/com.yufi.app.desktop"
    install -Dm644 packaging/com.yufi.app.svg \
      "$out/share/icons/hicolor/scalable/apps/com.yufi.app.svg"
  '';

  meta = {
    description = "Lightweight GTK4 Wi-Fi manager";
    homepage = "https://github.com/AtefR/YuFi";
    license = lib.licenses.mit;
    mainProgram = "yufi";
    platforms = lib.platforms.linux;
  };
}
