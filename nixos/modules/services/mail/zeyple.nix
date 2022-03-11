{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.services.zeyple;
  ini = pkgs.formats.ini { };

  gpgHome = pkgs.runCommand "zeyple-gpg-home" { } ''
    mkdir -p $out
    for file in ${lib.concatStringsSep " " cfg.keys}; do
      ${pkgs.gnupg}/bin/gpg --homedir="$out" --import "$file"
    done

    # Remove socket files
    rm -f $out/S.gpg-agent*
  '';
in {
  options.services.zeyple = {
    enable = mkEnableOption "Zeyple, an utility program to automatically encrypt outgoing emails with GPG";

    user = mkOption {
      type = types.str;
      default = "zeyple";
      description = ''
        User to run Zeyple as.

        <note><para>
          If left as the default value this user will automatically be created
          on system activation, otherwise the sysadmin is responsible for
          ensuring the user exists.
        </para></note>
      '';
    };

    group = mkOption {
      type = types.str;
      default = "zeyple";
      description = ''
        Group to use to run Zeyple.

        <note><para>
          If left as the default value this group will automatically be created
          on system activation, otherwise the sysadmin is responsible for
          ensuring the user exists.
        </para></note>
      '';
    };

    settings = mkOption {
      type = ini.type;
      default = { };
      description = ''
        Zeyple configuration. refer to
        <link xlink:href="https://github.com/infertux/zeyple/blob/master/zeyple/zeyple.conf.example"/>
        for details on supported values.
      '';
    };

    keys = mkOption {
      type = with types; listOf path;
      description = "List of public key files that will be imported by gpg.";
    };
  };

  config = mkIf cfg.enable {
    users.groups = optionalAttrs (cfg.group == "zeyple") { "${cfg.group}" = { }; };
    users.users = optionalAttrs (cfg.user == "zeyple") {
      "${cfg.user}" = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    services.zeyple.settings = {
      zeyple = mapAttrs (name: mkDefault) {
        log_file = "/var/log/zeyple.log";
        force_encrypt = true;
      };

      gpg = mapAttrs (name: mkDefault) { home = "${gpgHome}"; };

      relay = mapAttrs (name: mkDefault) {
        host = "localhost";
        port = 10026;
      };
    };

    environment.etc."zeyple.conf".source = ini.generate "zeyple.conf" cfg.settings;

    systemd.tmpfiles.rules = [ "f '${cfg.settings.zeyple.log_file}' 0600 ${cfg.user} ${cfg.group} - -" ];

    services.postfix.extraMasterConf = ''
      zeyple    unix  -       n       n       -       -       pipe
        user=${cfg.user} argv=${pkgs.zeyple}/bin/zeyple ''${recipient}

      localhost:${toString cfg.settings.relay.port} inet  n       -       n       -       10      smtpd
        -o content_filter=
        -o receive_override_options=no_unknown_recipient_checks,no_header_body_checks,no_milters
        -o smtpd_helo_restrictions=
        -o smtpd_client_restrictions=
        -o smtpd_sender_restrictions=
        -o smtpd_recipient_restrictions=permit_mynetworks,reject
        -o mynetworks=127.0.0.0/8,[::1]/128
        -o smtpd_authorized_xforward_hosts=127.0.0.0/8,[::1]/128
    '';

    services.postfix.extraConfig = "content_filter = zeyple";
  };
}
