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

{ lib, ... }:

let
  inherit (lib) types literalExpression;
  inherit (lib.options) mkOption mergeEqualOption;

  userType = types.mkOptionType {
    name = "user";
    description = "user email address string";
    descriptionClass = "noun";
    check = x: lib.isString x && builtins.match "^.+@.+$" x != null;
    merge = mergeEqualOption;
  };

  groupType = types.strMatching "^group:.+$";

  tagType = types.strMatching "^tag:.+$";

  autogroupType = types.strMatching "^autogroup:.+$";

  addressType = types.str // {
    name = "address";
    description = "string containing a network address";
    descriptionClass = "noun";
  };

  cidrType = types.str // {
    name = "cidr";
    description = "string containing a CIDR range";
    descriptionClass = "noun";
  };

  hostType = types.str // {
    name = "host";
    description = "string containing a hostname";
    descriptionClass = "noun";
  };

  protoType = types.either
    (types.coercedTo (types.ints.between 1 255) builtins.toString (types.strMatching "^[1-9]+$"))
    (types.enum [
      "igmp"
      "ipv4"
      "ip-in-ip"
      "tcp"
      "egp"
      "igp"
      "udp"
      "gre"
      "esp"
      "ah"
      "sctp"
    ]);
in

{
  options = {
    acls = mkOption {
      description = "Access control rules for your network.";
      default = [];
      type = types.listOf (types.submodule {
        options.action = mkOption {
          description = "Action for the rule. Only option is accept.";
          type = types.enum [ "accept" ];
          default = "accept";
        };

        options.src = mkOption {
          description = "A list of sources to which the rule applies.";
          type = types.listOf (types.oneOf [
            (types.enum [ "*" ])
            userType
            groupType
            addressType
            cidrType
            hostType
            tagType
            autogroupType
          ]);
        };

        options.dst = mkOption {
          description = "A list of destination devices and ports to which the rule applies.";
          type = types.listOf types.str;
        };

        options.proto = mkOption {
          description = "The protocol to which the rule applies.";
          type = types.nullOr protoType;
          default = null;
        };
      });
    };

    tagOwners = mkOption {
      description = "Defines the tags that can be applied to devices, and the list of users who are allowed to assign each tag.";
      default = {};
      type = types.attrsOf (types.listOf (types.oneOf [
        userType
        groupType
        autogroupType
        tagType
      ]));
      example = literalExpression "{ webserver = [ \"group:engineering\" ]; }";
    };

    hosts = mkOption {
      description = "Human-friendly names for IP addresses or CIDR ranges.";
      default = {};
      type = types.attrsOf (types.oneOf [
        addressType
        cidrType
      ]);
      example = literalExpression "{ example-host-1 = [ \"100.100.100.100\" ]; }";
    };

    groups = mkOption {
      description = "Lets you define a shorthand for a group of users, which you can then use in ACL rules instead of listing users out explicitly.";
      default = {};
      type = types.attrsOf (types.listOf types.str);
      example = literalExpression "{ engineering = [ \"dave@example.com\" \"laura@example.com\" ]; }";
    };

    ssh = mkOption {
      description = "List of users and devices that can use Tailscale SSH";
      default = [];
      type = types.listOf (types.submodule {
        options.action = mkOption {
          description = "Specifies whether to accept the connection or to perform additional checks on it.";
          type = types.enum ["accept" "check"];
          default = "accept";
        };

        options.src = mkOption {
          description = "The source where a connection originates from.";
          type = types.listOf types.str;
        };

        options.dst = mkOption {
          description = "The destination where the connection goes.";
          type = types.listOf types.str;
        };

        options.users = mkOption {
          description = "The set of allowed usernames on the host.";
          type = types.listOf types.str;
        };

        options.checkPeriod = mkOption {
          description = "When action is check, checkPeriod specifies the time period for which to allow a connection before requiring a check.";
          type = types.nullOr (types.strMatching "^[0-9]+[mh]$");
          default = null;
        };
      });
    };

    tests = mkOption {
      description = "Assertions about your access rules, which are checked whenever the tailnet policy file is changed.";
      default = [];
      type = types.listOf (types.submodule {
        options.src = mkOption {
          description = "The user identity being tested.";
          type = types.oneOf [
            userType
            groupType
            tagType
            hostType
          ];
        };

        options.proto = mkOption {
          description = "The IP protocol for accept and deny rules.";
          type = types.nullOr protoType;
          default = null;
        };

        options.accept = mkOption {
          description = "Destinations that the access rules should accept.";
          type = types.listOf types.str;
          default = [];
        };

        options.deny = mkOption {
          description = "Destinations that the access rules should deny.";
          type = types.listOf types.str;
          default = [];
        };
      });
    };
  };
}
