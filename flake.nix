{
  description = "Casseta & Planeta — Noite Animal: reverse engineering and the native Zig port";

  # Pinned to the host's channel. Zig releases move the std API, so the
  # toolchain is upgraded deliberately (same pins as the beni project).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.zig-overlay.url = "github:mitchellh/zig-overlay";
  inputs.zig-overlay.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, zig-overlay }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (system: pkgs: {
        default = pkgs.mkShell {
          packages = [
            # Zig 0.17.0 — the port (build.zig). Read its std (`zig env`)
            # rather than trusting remembered APIs.
            zig-overlay.packages.${system}."0.17.0"
            # Python is NOT from nix: uv installs and manages it (pinned in
            # .python-version). Run the tracker as `uv run noite …`.
            pkgs.uv
            pkgs.sqlite
            # For one-off scripts and `tools/oracle` (Unicorn).
            (pkgs.python3.withPackages (ps: [ ps.unicorn ]))
            # The port's platform layer (src/platform/sdl.zig): SDL3, found
            # through pkg-config. Declared by hand in Zig (no translate-c).
            pkgs.sdl3
            pkgs.pkg-config
            # General MIDI SoundFont for the MIDI synth
            # (src/platform/midi.zig); exported as NOITE_SOUNDFONT below.
            pkgs.soundfont-generaluser-gs
            # objdump -mi386 for the 32-bit code of segment 1000.
            pkgs.binutils
          ];

          # One global Zig cache for this project only, shared by every
          # worktree under work/ (each keeps its own local .zig-cache).
          shellHook = ''
            export ZIG_GLOBAL_CACHE_DIR="''${ZIG_GLOBAL_CACHE_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/zig-noite}"
            export NOITE_SOUNDFONT="''${NOITE_SOUNDFONT:-${pkgs.soundfont-generaluser-gs}/share/soundfonts/GeneralUser-GS.sf2}"
          '';
        };
      });
    };
}
