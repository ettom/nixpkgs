{ pkgs, lib, stdenv, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "zeyple";
  version = "cc125b7";

  src = fetchFromGitHub {
    owner = "infertux";
    repo = "zeyple";
    rev = "${version}";
    sha256 = "0r2d1drg2zvwmn3zg0qb32i9mh03r5di9q1yszx23r32rsax9mxh";
  };

  buildInputs = [ (pkgs.python39.withPackages (pythonPackages: with pythonPackages; [ pygpgme ])) ];
  installPhase = ''
    mkdir -p $out/bin
    cp $src/zeyple/zeyple.py $out/bin/zeyple
    chmod +x $out/bin/zeyple
  '';

  meta = {
    description = "Utility program to automatically encrypt outgoing emails with GPG";
    homepage = "https://infertux.com/labs/zeyple/";
    maintainers = with lib.maintainers; [ ettom ];
    license = lib.licenses.agpl3Plus;
    platforms = lib.platforms.all;
  };
}
