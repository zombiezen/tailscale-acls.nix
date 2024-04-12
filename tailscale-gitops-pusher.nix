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

{ buildGoModule, tailscale }:

buildGoModule {
  pname = "tailscale-gitops-pusher";

  inherit (tailscale) version src vendorHash ldflags;

  subPackages = [ "cmd/gitops-pusher" ];

  doCheck = false;

  meta = {
    description = "A small tool to help people achieve a GitOps workflow with Tailscale ACL changes.";
    mainProgram = "gitops-pusher";
    inherit (tailscale.meta) homepage license;
  };
}
