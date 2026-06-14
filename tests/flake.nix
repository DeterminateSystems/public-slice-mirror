{
  description = "A flake that builds a shell script output depending on hello";

  inputs.nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/secure-packages-rolling/0";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.writeTextFile {
            name = "hello-script";
            destination = "/bin/hello-script";
            executable = true;
            text = ''
              #!${pkgs.runtimeShell}
              export PATH="${pkgs.hello}/bin:$PATH"
              echo "Hello from a flake-built shell script!"
              hello
            '';
          };
        });
    };
}
