# Copyright 2024 Ross Light
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

{ self, pkgs, lib, runCommandLocal, testers, writeText }:

let
  defaultPolicy = {
    acls = [];
    groups = {};
    hosts = {};
    tagOwners = {};
    ssh = [];
    tests = [];
  };

  evalTests = {
    testDefaultPolicy = {
      expr = self.lib.evalTailscaleACLs { modules = []; };
      expected = defaultPolicy;
    };

    testACLs = {
      expr = self.lib.evalTailscaleACLs { modules = [
        {
          acls = [
            {
              src = [ "shreya@example.com" ];
              dst = [
                "100.101.102.103:80"
                "my-host:*"
              ];
            }
            {
              src = [ "shreya@example.com" ];
              dst = [ "100.101.102.103:53" ];
              proto = "udp";
            }
          ];
        }
      ]; };
      expected = defaultPolicy // {
        acls = [
          {
            action = "accept";
            src = [ "shreya@example.com" ];
            dst = [
              "100.101.102.103:80"
              "my-host:*"
            ];
          }
          {
            action = "accept";
            src = [ "shreya@example.com" ];
            dst = [ "100.101.102.103:53" ];
            proto = "udp";
          }
        ];
      };
    };

    testGroups = {
      expr = self.lib.evalTailscaleACLs { modules = [
        {
          groups.engineering = [
            "dave@example.com"
            "laura@example.com"
          ];

          groups.sales = [
            "brad@example.com"
            "alice@example.com"
          ];
        }
      ]; };
      expected = defaultPolicy // {
        groups = {
          "group:engineering" = [
            "dave@example.com"
            "laura@example.com"
          ];

          "group:sales" = [
            "brad@example.com"
            "alice@example.com"
          ];
        };
      };
    };

    testHosts = {
      expr = self.lib.evalTailscaleACLs { modules = [
        {
          hosts.example-host-1 = "100.100.100.100";
          hosts.example-network-1 = "100.100.101.100/24";
        }
      ]; };
      expected = defaultPolicy // {
        hosts = {
          example-host-1 = "100.100.100.100";
          example-network-1 = "100.100.101.100/24";
        };
      };
    };

    testTagOwners = {
      expr = self.lib.evalTailscaleACLs { modules = [
        {
          tagOwners.webserver = [ "group:engineering" ];
          tagOwners.secure-server = [
            "group:security-admins"
            "president@example.com"
          ];
          tagOwners.corp = [ "autogroup:member" ];
          tagOwners.monitoring = [];
        }
      ]; };
      expected = defaultPolicy // {
        tagOwners = {
          "tag:webserver" = [ "group:engineering" ];
          "tag:secure-server" = [
            "group:security-admins"
            "president@example.com"
          ];
          "tag:corp" = [ "autogroup:member" ];
          "tag:monitoring" = [];
        };
      };
    };

    testBroadPolicy = {
      expr = self.lib.evalTailscaleACLs { modules = [
        {
          acls = [
            {
              src = ["*"];
              dst = ["*:*"];
            }
          ];
          ssh = [
            {
              src = ["autogroup:member"];
              dst = ["autogroup:self"];
              users = ["root" "autogroup:nonroot"];
            }
            {
              src = ["autogroup:member"];
              dst = ["tag:prod"];
              users = ["root" "autogroup:nonroot"];
            }
            {
              src = ["tag:logging"];
              dst = ["tag:prod"];
              users = ["root" "autogroup:nonroot"];
            }
          ];
        }
      ]; };
      expected = defaultPolicy // {
        acls = [
          {
            action = "accept";
            src = ["*"];
            dst = ["*:*"];
          }
        ];
        ssh = [
          {
            action = "accept";
            src = ["autogroup:member"];
            dst = ["autogroup:self"];
            users = ["root" "autogroup:nonroot"];
          }
          {
            action = "accept";
            src = ["autogroup:member"];
            dst = ["tag:prod"];
            users = ["root" "autogroup:nonroot"];
          }
          {
            action = "accept";
            src = ["tag:logging"];
            dst = ["tag:prod"];
            users = ["root" "autogroup:nonroot"];
          }
        ];
      };
    };

    testTests = {
      expr = self.lib.evalTailscaleACLs { modules = [
        {
          tests = [
            {
              src = "dave@example.com";
              proto = "tcp";
              accept = [ "example-host-1:22" "vega:80" ];
              deny = [ "1.2.3.4:443" ];
            }
            {
              src = "ross@example.com";
              accept = [ "good.example.com:80" ];
              deny = [ "bad.example.com:80" ];
            }
          ];
        }
      ]; };
      expected = defaultPolicy // {
        tests = [
          {
            src = "dave@example.com";
            proto = "tcp";
            accept = [ "example-host-1:22" "vega:80" ];
            deny = [ "1.2.3.4:443" ];
          }
          {
            src = "ross@example.com";
            accept = [ "good.example.com:80" ];
            deny = [ "bad.example.com:80" ];
          }
        ];
      };
    };
  };

  failureToString = { name, expected, result }: ''
    ${name} failed!
    want:
    ${builtins.toJSON expected}

    got:
    ${builtins.toJSON result}
  '';
in

{
  checks.eval = runCommandLocal "tailscale-acls-tests" {
    failures = lib.strings.concatStringsSep "\n\n" (builtins.map failureToString (lib.debug.runTests evalTests));
    passAsFile = ["failures"];
  } ''
    if [[ -s "$failuresPath" ]]; then
      cat "$failuresPath" >&2
      exit 1
    else
      touch "$out"
      exit 0
    fi
  '';

  checks.writePolicy = testers.testEqualContents {
    assertion = "writePolicy writes formatted JSON";
    actual = self.lib.writePolicy {
      inherit pkgs;
      policy = {
        acls = [
          {
              action = "accept";
              src = ["*"];
              dst = ["*:*"];
          }
        ];
      };
    };
    expected = writeText "expected.hujson" ''
      {
        "acls": [
          {
            "action": "accept",
            "dst": [
              "*:*"
            ],
            "src": [
              "*"
            ]
          }
        ]
      }
    '';
  };

  checks.writePolicyWarning = testers.testEqualContents {
    assertion = "writePolicy writes a warning to file if requested";
    actual = self.lib.writePolicy {
      inherit pkgs;
      policy = {
        acls = [
          {
              action = "accept";
              src = ["*"];
              dst = ["*:*"];
          }
        ];
      };
      warning = "This file is maintained elsewhere.\nNext line!";
    };
    expected = writeText "expected.hujson" ''
      // DO NOT EDIT. This file is maintained elsewhere.
      // Next line!
      {
        "acls": [
          {
            "action": "accept",
            "dst": [
              "*:*"
            ],
            "src": [
              "*"
            ]
          }
        ]
      }
    '';
  };
}
