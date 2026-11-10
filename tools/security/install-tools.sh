#!/usr/bin/env bash
set -euo pipefail
mkdir -p .validation/bin .validation/downloads
fetch() {
  local name="$1" url="$2" checksum="$3" archive=".validation/downloads/$1.tar.gz"
  curl --fail --location --silent --show-error --retry 3 "$url" -o "$archive"
  printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status
  tar -xzf "$archive" -C .validation/bin "$name"
}
fetch kubeconform https://github.com/yannh/kubeconform/releases/download/v0.8.0/kubeconform-linux-amd64.tar.gz 9bc2bffbf71f261128533edaf912153948b7ff238f9a531ae6d34466ec287883
fetch conftest https://github.com/open-policy-agent/conftest/releases/download/v0.71.1/conftest_0.71.1_Linux_x86_64.tar.gz c3f6b2a753bd56e377a1e51a95ae3e057f926f2e9139f7d5b5dfbbaf810f7985
fetch actionlint https://github.com/rhysd/actionlint/releases/download/v1.7.12/actionlint_1.7.12_linux_amd64.tar.gz 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8
archive=.validation/downloads/helm.tar.gz
curl --fail --location --silent --show-error --retry 3 https://get.helm.sh/helm-v3.22.1-linux-amd64.tar.gz -o "$archive"
printf '%s  %s\n' 896cf63684a42a723d61c980369d6e588330927deb13676ca0d85006dd6da0ea "$archive" | sha256sum --check --status
tar -xzf "$archive" -C .validation/downloads linux-amd64/helm
cp .validation/downloads/linux-amd64/helm .validation/bin/helm
chmod +x .validation/bin/*
