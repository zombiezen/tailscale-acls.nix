# Tailscale ACLs using the Nix module system

This repository contains a [Nix flake](https://nixos.wiki/wiki/Flakes)
that enables managing [Tailscale ACLs](https://tailscale.com/kb/1337/acl-syntax)
using the [Nix module system](https://nixos.org/manual/nixpkgs/unstable/#module-system).

Using the Nix module system for Tailscale ACLs
allows writing complex or reusable rules using the Nix language.
A policy like this:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["dave@example.com"],
      "dst": [
        "example-host-1:*",
        "vega:80,443"
      ]
    }
  ],
  "hosts": {
    "example-host-1": "100.100.100.100",
    "vega": "100.101.102.103",
  },
  "tests": [
    {
      "src": "dave@example.com",
      "proto": "tcp",
      "accept": ["example-host-1:22", "vega:80"],
      "deny": ["1.2.3.4:443"],
    },
  ]
}
```

Can be rewritten to this:

```nix
let
  admin = "dave@example.com";
in

{
  acls = [
    {
      src = [admin];
      dst = [
        "example-host-1:*"
        "vega:80,443"
      ];
    }
  ];

  hosts.example-host-1 = "100.100.100.100";
  hosts.vega = "100.101.102.103";

  tests = [
    {
      src = admin;
      proto = "tcp";
      accept = ["example-host-1:22" "vega:80"];
      deny = ["1.2.3.4:443"];
    }
  ];
}
```

You can also split up your configuration into multiple files
using the `imports` syntax.

## License

[Apache 2.0](LICENSE)
