#!/usr/bin/env bash

action=${1:-install}

if [ "$action" == "install" ]; then
  # Create the distrobox container
  if ! distrobox list | grep -q "google"; then
    distrobox-create \
    --name google \
    --image registry.fedoraproject.org/fedora-toolbox:latest \
    --volume /home/linuxbrew/.linuxbrew:/home/linuxbrew/.linuxbrew:ro,z \
    --additional-packages "bash-completion bc bzip2 cracklib-dicts curl diffutils dnf-plugins-core findutils glibc-all-langpacks glibc-common glibc-locale-source gnupg2 gnupg2-smime hostname iproute iputils keyutils krb5-libs less lsof man-db man-pages mtr ncurses nss-mdns openssh-clients pam passwd pigz pinentry procps-ng rsync shadow-utils sudo tcpdump time traceroute tree tzdata unzip util-linux vte-profile wget which whois words xorg-x11-xauth xz zip mesa-dri-drivers mesa-vulkan-drivers nu vulkan" \
    --yes
  else
    echo "Container 'google' already exists. Proceeding to install packages..."
  fi

  # Install packages inside the container
  distrobox-enter --name google -- bash -c '
  # repo: google chrome
  sudo dnf -y install fedora-workstation-repositories
  sudo dnf config-manager setopt google-chrome.enabled=1
  # repo: antigravity ide
  sudo tee /etc/yum.repos.d/antigravity.repo << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOL
  sudo dnf makecache
  # install and export to host
  sudo dnf -y install antigravity google-chrome-stable
  distrobox-export --app antigravity --export-label none
  distrobox-export --app google-chrome --export-label none
  '

elif [ "$action" == "update" ]; then
  if distrobox list | grep -q "google"; then
    echo "Updating 'google' container..."
    distrobox-enter --name google -- sudo dnf update -y antigravity google-chrome-stable
  else
    echo "Container 'google' does not exist. Please run install first."
    exit 1
  fi
else
  echo "Usage: $0 [install|update]"
  exit 1
fi
