#!/bin/bash

while true; do
  echo "Running pod install..."
  pod install 2>&1 | tee /tmp/pod_install.log

  # Check if installation succeeded
  if grep -q "Pod installation complete" /tmp/pod_install.log; then
    echo "✅ Pod install succeeded!"
    break
  fi

  # Find the error line containing the git clone command
  error_line=$(grep "git clone" /tmp/pod_install.log | head -1)
  if [ -z "$error_line" ]; then
    echo "❌ No git clone error found. Check log manually."
    break
  fi

  # Extract the repo URL and temp path
  repo_url=$(echo "$error_line" | grep -oE 'https://[^ ]+\.git')
  temp_path=$(echo "$error_line" | grep -oE '/var/folders/[^ ]+')

  echo "Manual cloning $repo_url into $temp_path..."
  git -c http.version=HTTP/1.1 -c http.postBuffer=2097152000 -c http.lowSpeedLimit=0 -c http.lowSpeedTime=999999 clone --depth 1 --single-branch --no-tags "$repo_url" "$temp_path"

  # If the clone fails, try SSH (if configured) or tarball
  if [ $? -ne 0 ]; then
    echo "Git clone failed. Trying tarball download..."
    # Extract branch from the error (e.g., --branch v1.2.3)
    branch=$(echo "$error_line" | grep -oE '\-\-branch [^ ]+' | cut -d' ' -f2)
    # Download tarball of that branch
    curl -L --retry 10 --retry-delay 5 -C - -o /tmp/repo.tar.gz "https://github.com/$(echo "$repo_url" | sed 's|https://github.com/||;s|\.git||')/archive/refs/tags/$branch.tar.gz"
    # If tag fails, try heads
    if [ $? -ne 0 ]; then
      curl -L --retry 10 --retry-delay 5 -C - -o /tmp/repo.tar.gz "https://github.com/$(echo "$repo_url" | sed 's|https://github.com/||;s|\.git||')/archive/refs/heads/$branch.tar.gz"
    fi
    mkdir -p "$temp_path"
    tar -xzf /tmp/repo.tar.gz -C "$temp_path" --strip-components=1
  fi

  echo "Retrying pod install..."
done

# EVERTIME WHEN I RUN THIS SCRIPT please use the following command to ensure that the script has executable permissions:
# ```bash
# chmod +x frontend/mobile_app/ios/fix_pods.sh
# ```