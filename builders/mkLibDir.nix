{
  pkgs,
  fetchAssetFromHash,
  fetchSha1,
  lib,
  ...
}: {
  libraries,
  excludeCoordinates ? [],
  dedupArtifacts ? false,
}: let
  inherit (lib) pipe;
  inherit
    (lib.nixcraft.maven)
    filterLibrariesByOS
    filterClassifiers
    filterEmptyArtifactUrl
    filterLibsByCoordinates
    dedupLibsByArtifact
    toLibraryArtifactLinkTree
    ;

  # TODO: add support for osx
  librariesLinkTree = pipe libraries [
    (filterLibrariesByOS "linux")
    filterClassifiers
    filterEmptyArtifactUrl
    (filterLibsByCoordinates excludeCoordinates)
    (libs:
      if dedupArtifacts
      then dedupLibsByArtifact libs
      else libs)
    (toLibraryArtifactLinkTree fetchSha1)
  ];
in
  pkgs.linkFarm "minecraft-lib-dir" librariesLinkTree
