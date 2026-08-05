{
  lib,
  fetchFabricLoaderImpure,
  sources,
  ...
}: {config, ...}: let
  loaderVersions = lib.attrNames sources.fabric.lock;
  latestLoaderVersion = lib.foldl' (
    latest: version:
      if builtins.compareVersions version latest > 0
      then version
      else latest
  ) (builtins.head loaderVersions) (builtins.tail loaderVersions);
in {
  options = {
    enable = lib.mkEnableOption "fabric loader";

    version = lib.mkOption {
      type = lib.types.nonEmptyStr;
      default = latestLoaderVersion;
      defaultText = lib.literalExpression ''latest Fabric Loader version in sources/fabric/lock.json'';
      description = ''
        Fabric Loader version. Defaults to the latest version available in the
        repository's Fabric lock file.
      '';
    };

    minecraftVersion = lib.nixcraft.options.minecraftVersionDyn;

    hash = lib.mkOption {
      type = lib.types.nonEmptyStr;
    };

    _instanceType = lib.mkOption {
      type = lib.types.enum ["client" "server"];
      internal = true;
    };

    _impurePackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      defaultText = ''package'';
      default = fetchFabricLoaderImpure {
        mcVersion = config.minecraftVersion;
        loaderVersion = config.version;
        client = config._instanceType == "client";
        server = config._instanceType == "server";
        hash = config.hash;
      };
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
      defaultText = ''meta'';
      default =
        {
          clientMainClass = "net.fabricmc.loader.impl.launch.knot.KnotClient";
          serverMainClass = "net.fabricmc.loader.impl.launch.knot.KnotServer";
        }
        // {
          lock = sources.fabric.lock.${config.version};
          gameLock = sources.fabric.game-lock.${config.minecraftVersion};
        };
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
