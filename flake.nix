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

{
  description = "Tailscale ACLs using the Nix module system";

  inputs = {
    nixpkgs.url = "nixpkgs";
    flake-utils.url = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      evalModules = args: nixpkgs.lib.evalModules (args // {
        modules = [ ./schema.nix ] ++ (args.modules or []);
        class = "tailscaleACLs";
      });
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.tailscale-gitops-pusher = pkgs.callPackage ./tailscale-gitops-pusher.nix {};
        packages.docs = (pkgs.nixosOptionsDoc {
          options = builtins.removeAttrs (evalModules {}).options ["_module"];
        }).optionsCommonMark;

        checks = (pkgs.callPackage ./checks.nix { inherit self; }).checks;
      }
    ) // {
      lib.evalTailscaleACLs = { modules ? [] }:
        let
          inherit (builtins) map;
          inherit (nixpkgs.lib.attrsets) filterAttrs mapAttrs';
          evaled = evalModules { inherit modules; };

          removeNullAttrs = keys: filterAttrs (k: v: !(builtins.isNull v && builtins.elem k keys));
        in {
          inherit (evaled.config) hosts;

          acls = map (removeNullAttrs ["proto"]) evaled.config.acls;
          groups = mapAttrs' (name: value: { name = "group:${name}"; inherit value; }) evaled.config.groups;
          tagOwners = mapAttrs' (name: value: { name = "tag:${name}"; inherit value; }) evaled.config.tagOwners;
          ssh = map (removeNullAttrs ["checkPeriod"]) evaled.config.ssh;
          tests = map (removeNullAttrs ["proto"]) evaled.config.tests;
        };

      lib.writePolicy = { pkgs, policy, warning ? null }:
        let
          inherit (pkgs.lib.strings) concatMapStrings splitString;
        in
        pkgs.callPackage ({ runCommand, jq }:
          runCommand "policy.hujson" {
            nativeBuildInputs = [ jq ];
            policy = builtins.toJSON policy;
            warning = if builtins.isNull warning
              then null
              else concatMapStrings (line: "// ${line}\n") (splitString "\n" ("DO NOT EDIT. " + warning));
            passAsFile = ["policy" "warning"];
          } ''
            if [[ -s "$warningPath" ]]; then
              cp "$warningPath" "$out"
            fi
            jq . "$policyPath" >> "$out"
          ''
        ) {};
    };
}
