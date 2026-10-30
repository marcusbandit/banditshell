{ pkgs, ... }:

let
  helper = pkgs.runCommand "banditshell-charge-limit" { } ''
    install -Dm755 ${../scripts/charge-limit.sh} $out/bin/banditshell-charge-limit
    install -Dm644 ${../assets/polkit/org.banditshell.charge-limit.policy} $out/share/polkit-1/actions/org.banditshell.charge-limit.policy
    substituteInPlace $out/share/polkit-1/actions/org.banditshell.charge-limit.policy \
      --replace-fail /usr/local/libexec/banditshell-charge-limit /run/current-system/sw/bin/banditshell-charge-limit
  '';
in
{
  security.polkit.enable = true;
  environment.systemPackages = [ helper ];
}
