{
  lib,
  sources,
  ...
}: {config, ...}: {
  options = {
    enable = lib.mkEnableOption "quilt loader";

    version = lib.mkOption {
      type = lib.types.nonEmptyStr;
    };

    minecraftVersion = lib.nixcraft.options.minecraftVersionDyn;

    hash = lib.mkOption {
      type = lib.types.nonEmptyStr;
    };

    _instanceType = lib.mkOption {
      type = lib.types.enum ["client" "server"];
      internal = true;
    };

    dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Maven coordinates of the libraries provided by the loader.
        Instances use them to drop the vanilla copies of the same artifacts.
      '';
    };

    classes = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      readOnly = true;
    };

    meta = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        lock = sources.quilt.lock.${config.version};
        gameLock = sources.quilt.game-lock.${config.minecraftVersion};
      };
      defaultText = ''meta'';
    };
  };

  config = {
    hash = lib.mkOptionDefault lib.fakeHash;

    dependencies =
      config.meta.lock.dependencies.common
      ++ config.meta.lock.dependencies.${config._instanceType}
      ++ config.meta.gameLock.dependencies ++ [config.meta.lock.name];

    classes = let
      inherit (lib.nixcraft.maven) mkLibUrl;
      inherit (sources) maven-libraries;
    in
      map (library:
        builtins.fetchurl {
          url = mkLibUrl maven-libraries.${library}.url library;
          sha256 = maven-libraries.${library}.sha256;
        })
      config.dependencies;
  };
}
