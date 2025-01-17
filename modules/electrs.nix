{ config, lib, pkgs, ... }:

with lib;
let
  options.services.electrs = {
    enable = mkEnableOption "electrs";
    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address to listen for RPC connections.";
    };
    port = mkOption {
      type = types.port;
      default = 50001;
      description = "RPC port.";
    };
    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/electrs";
      description = "The data directory for electrs.";
    };
    high-memory = mkOption {
      type = types.bool;
      default = false;
      description = ''
        If enabled, the electrs service will sync faster on high-memory systems (≥ 8GB).
      '';
    };
    monitoringPort = mkOption {
      type = types.port;
      default = 4224;
      description = "Prometheus monitoring port.";
    };
    extraArgs = mkOption {
      type = types.separatedString " ";
      default = "";
      description = "Extra command line arguments passed to electrs.";
    };
    user = mkOption {
      type = types.str;
      default = "electrs";
      description = "The user as which to run electrs.";
    };
    group = mkOption {
      type = types.str;
      default = cfg.user;
      description = "The group as which to run electrs.";
    };
    enforceTor = nbLib.enforceTor;
  };

  cfg = config.services.electrs;
  nbLib = config.nix-bitcoin.lib;
  secretsDir = config.nix-bitcoin.secretsDir;
  bitcoind = config.services.bitcoind;
in {
  inherit options;

  config = mkIf cfg.enable {
    assertions = [
      { assertion = bitcoind.prune == 0;
        message = "electrs does not support bitcoind pruning.";
      }
    ];

    services.bitcoind.enable = true;

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0770 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.electrs = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "bitcoind.service" ];
      after = [ "bitcoind.service" ];
      preStart = ''
        echo "auth = \"${bitcoind.rpc.users.public.name}:$(cat ${secretsDir}/bitcoin-rpcpassword-public)\"" \
          > electrs.toml
        '';
      serviceConfig = nbLib.defaultHardening // {
        RuntimeDirectory = "electrs";
        RuntimeDirectoryMode = "700";
        WorkingDirectory = "/run/electrs";
        ExecStart = ''
          ${config.nix-bitcoin.pkgs.electrs}/bin/electrs -vvv \
          ${if cfg.high-memory then
              traceIf (!bitcoind.dataDirReadableByGroup) ''
                Warning: For optimal electrs syncing performance, enable services.bitcoind.dataDirReadableByGroup.
                Note that this disables wallet support in bitcoind.
              '' ""
            else
              "--jsonrpc-import --index-batch-size=10"
          } \
          --network=${bitcoind.makeNetworkName "bitcoin" "regtest"} \
          --db-dir='${cfg.dataDir}' \
          --daemon-dir='${bitcoind.dataDir}' \
          --electrum-rpc-addr=${cfg.address}:${toString cfg.port} \
          --monitoring-addr=${cfg.address}:${toString cfg.monitoringPort} \
          --daemon-rpc-addr=${bitcoind.rpc.address}:${toString bitcoind.rpc.port} \
          ${cfg.extraArgs}
        '';
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "10s";
        ReadWritePaths = "${cfg.dataDir} ${if cfg.high-memory then "${bitcoind.dataDir}" else ""}";
      } // nbLib.allowedIPAddresses cfg.enforceTor;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "bitcoinrpc-public" ] ++ optionals cfg.high-memory [ bitcoind.user ];
    };
    users.groups.${cfg.group} = {};
  };
}
