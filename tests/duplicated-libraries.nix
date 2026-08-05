{
  lib,
  pkgs,
}: let
  inherit
    (lib.nixcraft.maven)
    parseCoordinate
    artifactKey
    filterLibsByCoordinates
    dedupLibsByArtifact
    ;

  mkLibrary = name: {inherit name;};
  names = libraries: map (library: library.name) libraries;

  # Vanilla 1.21.10 ships asm 9.6 while fabric loader 0.18.1 brings 9.9,
  # which crashes the client at launch when both are found on classpath
  vanillaLibraries = map mkLibrary [
    "org.ow2.asm:asm:9.6"
    "org.joml:joml:1.10.8"
    "org.lwjgl:lwjgl:3.4.1"
    "org.lwjgl:lwjgl:3.4.1:natives-linux"
  ];

  loaderDependencies = [
    "org.ow2.asm:asm:9.9"
    "net.fabricmc:fabric-loader:0.18.1"
  ];

  filtered = names (filterLibsByCoordinates loaderDependencies vanillaLibraries);

  deduped = names (dedupLibsByArtifact (map mkLibrary [
    "org.ow2.asm:asm:9.6"
    "org.joml:joml:1.10.8"
    "org.ow2.asm:asm:9.9"
  ]));

  coordinateWithClassifier = parseCoordinate "org.lwjgl:lwjgl:3.4.1:natives-linux";
  coordinateWithoutClassifier = parseCoordinate "org.ow2.asm:asm:9.6";
in
  pkgs.runCommandLocal "nixcraft-duplicated-libraries-test" {} ''
    ${assert coordinateWithClassifier.groupId == "org.lwjgl"; ""}
    ${assert coordinateWithClassifier.artifactId == "lwjgl"; ""}
    ${assert coordinateWithClassifier.version == "3.4.1"; ""}
    ${assert coordinateWithClassifier.classifier == "natives-linux"; ""}
    ${assert coordinateWithoutClassifier.classifier == null; ""}

    ${assert artifactKey "org.ow2.asm:asm:9.6" == "org.ow2.asm:asm"; ""}
    ${assert artifactKey "org.lwjgl:lwjgl:3.4.1:natives-linux" == "org.lwjgl:lwjgl:natives-linux"; ""}

    # The vanilla asm goes away, everything else stays, natives included
    ${assert filtered == ["org.joml:joml:1.10.8" "org.lwjgl:lwjgl:3.4.1" "org.lwjgl:lwjgl:3.4.1:natives-linux"]; ""}

    # Only one version of every artifact survives, the last one wins
    ${assert lib.sort (a: b: a < b) deduped == ["org.joml:joml:1.10.8" "org.ow2.asm:asm:9.9"]; ""}

    touch $out
  ''
