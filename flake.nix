{
  description = "micropython development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      systems = nixpkgs.lib.platforms.unix;
      eachSystem =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              config = { };
              overlays = [ ];
            }
          )
        );

      mkLuna =
        {
          zlib,
          stdenv,
          fetchFromGitHub,
        }:
        let
          version = "2.1";
          pname = "luna";
        in
        stdenv.mkDerivation {
          inherit version pname;
          src = fetchFromGitHub {
            owner = "ndless-nspire";
            repo = "Luna";
            rev = "v${version}";
            hash = "sha256-3muTmw3sHLuh5s6Vm7/qTu3SMMoLIucjc5HKX62ZzMk=";
          };
          installPhase = ''
            make install PREFIX="$out/bin"
          '';
          nativeBuildInputs = [ zlib ];
        };
      mkTns =
        {
          lib,
          bash,
          stdenv,
          coreutils,
          callPackage,
          luna ? null,
        }:
        let
          fs = lib.fileset;
          root = ./.;
          luna' = if luna == null then callPackage mkLuna { } else luna;
        in
        derivation {
          inherit (stdenv.hostPlatform) system;
          name = "digcod-tns";
          builder = "${bash}/bin/bash";
          src = fs.toSource {
            inherit root;
            fileset = fs.intersection (fs.gitTracked root) (fs.fileFilter (f: f.hasExt "py") root);
          };
          args = [
            "-c"
            ''${coreutils}/bin/mkdir -p "$out" && ${luna'}/bin/luna "$src/"*.py "$out/DigiCod_Nspire.tns"''
          ];
        };
    in
    {
      devShells = eachSystem (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = with pkgs; [
            micropython
            self.packages.${pkgs.stdenv.hostPlatform.system}.luna
          ];
        };
      });

      overlays.default = _: _: {
        luna = mkLuna;
        digcod-tns = mkTns;
      };

      packages = eachSystem (
        pkgs:
        let
          luna = pkgs.callPackage mkLuna { };
          digcod-tns = pkgs.callPackage mkTns { };
        in
        {
          inherit luna digcod-tns;
          default = luna;
        }
      );

      apps = eachSystem (
        pkgs:
        pkgs.lib.mapAttrs (_: drv: {
          type = "app";
          program = "${drv}${drv.passthru.exePath or "/bin/${drv.pname or drv.name}"}";
        }) self.packages.${pkgs.stdenv.hostPlatform.system}
      );
    };
}
