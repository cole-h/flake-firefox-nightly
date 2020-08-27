{
  description = "firefox-nightly";

  # TODO: should warn whenever flakes are resolved to different versions (names of flakes should match repo names?)
  inputs = {
    master = { url = "github:nixos/nixpkgs/master"; };
    nixpkgs = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    cachixpkgs = { url = "github:nixos/nixpkgs/nixos-20.03"; };
    mozilla = { url = "github:colemickens/nixpkgs-mozilla"; flake = false; };
    flake-utils = { url = "github:numtide/flake-utils"; }; # TODO: adopt this
  };

  outputs = inputs:
    let
      inherit (sysPkgs.lib.firefoxOverlay) firefox_versions;

      metadata = version: builtins.fromJSON (builtins.readFile (./. + "/${version}.json"));

      nameValuePair = name: value: { inherit name value; };
      genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
      forAllSystems = genAttrs [ "x86_64-linux" "i686-linux" "aarch64-linux" ];

      pkgsFor = pkgs: system:
        import pkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ (import "${inputs.mozilla}/firefox-overlay.nix") ];
        };

      # impure, but that's by design
      sysPkgs = (pkgsFor inputs.nixpkgs builtins.currentSystem);

      variants = system: {
        firefox-nightly-bin =
          let
            meta = metadata "nightly";
          in
          (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefoxVersion (
            meta.version // { info = meta.cachedInfo; }
          );
        firefox-beta-bin =
          let
            meta = metadata "beta";
          in
          (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefoxVersion (
            meta.version // { info = meta.cachedInfo; }
          );
        firefox-bin =
          let
            meta = metadata "stable";
          in
          (pkgsFor inputs.nixpkgs system).lib.firefoxOverlay.firefoxVersion (
            meta.version // { info = meta.cachedInfo; }
          );
      };
    in
    rec {
      devShell =
        forAllSystems (system:
          let
            master_ = pkgsFor inputs.master system;
            nixpkgs_ = pkgsFor inputs.nixpkgs system;
            cachixpkgs_ = pkgsFor inputs.cachixpkgs system;
          in
          nixpkgs_.mkShell {
            nativeBuildInputs = with nixpkgs_; [
              bash
              cacert
              curl
              git
              jq
              openssh
              ripgrep
              cachixpkgs_.cachix
              master_.nixFlakes
              master_.nix-build-uncached
            ];
          }
        );

      packages = forAllSystems (system:
        let
          nixpkgs_ = (pkgsFor inputs.nixpkgs system);
          attrValues = inputs.nixpkgs.lib.attrValues;
        in
        (variants system)
      );

      latest = version:
        let
          pkgs = pkgsFor inputs.nixpkgs builtins.currentSystem;
          cachedInfo = pkgs.lib.firefoxOverlay.versionInfo version;
        in
        { inherit version cachedInfo; };

      nightly = latest {
        name = "Firefox Nightly";
        version = firefox_versions.FIREFOX_NIGHTLY;
        release = false;
      };

      beta = latest {
        name = "Firefox Beta";
        version = firefox_versions.LATEST_FIREFOX_DEVEL_VERSION;
        release = true;
      };

      stable = latest {
        name = "Firefox";
        version = firefox_versions.LATEST_FIREFOX_VERSION;
        release = true;
      };

      # defaultPackage = forAllSystems (system:
      #   let
      #     nixpkgs_ = (pkgsFor inputs.nixpkgs system);
      #     attrValues = inputs.nixpkgs.lib.attrValues;
      #   in
      #   nixpkgs_.symlinkJoin {
      #     name = "flake-firefox-nightly";
      #     paths = attrValues (variants system);
      #   }
      # );
    };
}
