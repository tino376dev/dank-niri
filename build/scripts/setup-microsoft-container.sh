#!/usr/bin/env bash

action=${1:-install}

if [ "$action" == "install" ]; then
  # Create the distrobox container
  if ! distrobox list | grep -q "microsoft"; then
    distrobox-create \
      --name microsoft \
      --image registry.fedoraproject.org/fedora-toolbox:latest \
      --volume /home/linuxbrew/.linuxbrew:/home/linuxbrew/.linuxbrew:ro,z \
      --additional-packages "xdg-desktop-portal bash-completion bc bzip2 cracklib-dicts curl diffutils dnf-plugins-core findutils glibc-all-langpacks glibc-common glibc-locale-source gnupg2 gnupg2-smime hostname iproute iputils keyutils krb5-libs less lsof man-db man-pages mtr ncurses nss-mdns openssh-clients pam passwd pigz pinentry procps-ng rsync shadow-utils sudo tcpdump time traceroute tree tzdata unzip util-linux vte-profile wget which whois words xorg-x11-xauth xz zip mesa-dri-drivers mesa-vulkan-drivers nu vulkan" \
      --yes
  else
    echo "Container 'microsoft' already exists. Proceeding to install packages..."
  fi

  # Install packages inside the container
  distrobox-enter --name microsoft -- bash -c '
  # set up sharing
  sudo ln -s /run/host/run/systemd/system /run/systemd
  sudo mkdir -p /run/dbus
  sudo ln -s /run/host/run/dbus/system_bus_socket /run/dbus/system_bus_socket
  # microsoft signing keys
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  # repo: microsoft edge
  sudo dnf config-manager addrepo --from-repofile https://packages.microsoft.com/yumrepos/edge/config.repo --save-filename edge
  # repo: vscode
  sudo dnf config-manager addrepo --from-repofile https://packages.microsoft.com/yumrepos/vscode/config.repo --save-filename vscode
  # install and export
  sudo dnf -y install code-insiders microsoft-edge-stable
  distrobox-export --app code-insiders --export-label none
  distrobox-export --app microsoft-edge-stable --export-label none
  '

elif [ "$action" == "update" ]; then
  if distrobox list | grep -q "microsoft"; then
    echo "Updating 'microsoft' container..."
    distrobox-enter --name microsoft -- sudo dnf update -y code-insiders microsoft-edge-stable
  else
    echo "Container 'microsoft' does not exist. Please run install first."
    exit 1
  fi
else
  echo "Usage: $0 [install|update]"
  exit 1
fi
