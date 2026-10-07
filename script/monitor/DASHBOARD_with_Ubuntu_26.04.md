
How to setup a monitoring dashboard
===================================

Inspired by: https://pimylifeup.com/ubuntu-chromium-kiosk/

Steps
-----



### 1.) Install Ubuntu Server (no desktop) on your computer than set hostname and timezone.

```sh
hostnamectl set-hostname check.local
timedatectl set-timezone Europe/Berlin
```



### 2.) Install minimal GUI and Tools.

```sh
apt install ubuntu-desktop-minimal
apt install language-pack-gnome-de
apt install dbus-x11
apt install ydotool
```



### 3.) Create a kiosk user with home-directory.

```sh
useradd -m kiosk
```

and disable Welocme-Screen
```sh
echo "yes" > /home/kiosk/.config/gnome-initial-setup-done
```



### 4.) Edit following file `nano /etc/gdm3/custom.conf` to turn on autologin for user 'kiosk'.

```
[daemon]
# Uncomment the line below to force the login screen to use Xorg
#WaylandEnable=false

# Enabling automatic login
#  AutomaticLoginEnable = true
#  AutomaticLogin = user1

AutomaticLoginEnable = true
AutomaticLogin = kiosk
```



### 5.) Configure GUI of user kiosk to prevent monitor from sleeping

```sh
#gsettings list-recursively

# Does not work
#sudo -u kiosk gsettings set org.gnome.desktop.session idle-delay 0

# Set idle-delay from "uint32 300" to "uint32 0", needs 'apt install dbus-x11'
# You can check the value in "GUI-Session of kiosk -> Settings -> Power"
sudo -u kiosk dbus-launch dconf write /org/gnome/desktop/session/idle-delay "uint32 0"
```



### 6.) Create custom script in home of kiosk to be started via autostart in the desktop environment.

Therefore open the executable script file `/home/kiosk/kiosk-loop.sh`:

```sh
touch /home/kiosk/kiosk-loop.sh
chmod +x /home/kiosk/kiosk-loop.sh
nano /home/kiosk/kiosk-loop.sh
```

Paste the following content into the opened file:
```
#!/bin/bash

# Wait until desktop loaded completely.
sleep 5

while true; do

    # Background process waiting until Firefox is open to move the mouse pointer away.
    (sleep 10 && ydotool mousemove 4096 2160) &

    # Always a fresh firefox on each start
    rm -rf /home/kiosk/snap/firefox/common

    # Starts Firefox in mode kiosk. (The instruction pointer keeps moving after Firefox has closed.)
    snap run firefox -fullscreen -kiosk -url http://monitor.everbrent.net/check.html

    # In case of a crash wait 5 seconds and restart
    sleep 5
done
```



### 7.) Enable script launch unsing autostart

Therefore open the configuration file `/home/kiosk/.config/autostart/kiosk.desktop`:

```sh
mkdir -p /home/kiosk/.config/autostart
nano /home/kiosk/.config/autostart/kiosk.desktop
```

Paste the following content into the opened file:
```
[Desktop Entry]
Type=Application
Name=Firefox Kiosk
Exec=/home/kiosk/kiosk-loop.sh
X-GNOME-Autostart-enabled=true
```



### 8.) Prevent firefox from asking stuff after its start. (Maybe optional if firefox is installed via snap)

Therefore open the configuration file `/home/kiosk/.config/autostart/kiosk.desktop`:

```sh
mkdir -p /etc/firefox/policies
nano /etc/firefox/policies/policies.json
```

Paste the following content into the opened file:
```
{
  "policies": {
    "DontCheckDefaultBrowser": true,
    "DisableProfileImport": true,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "DisableTelemetry": true,
    "DisableAppUpdate": true,
    "DisableDefaultBrowserAgent": true,
    "DisableFirefoxStudies": true,
    "UserMessaging": {
      "SkipOnboarding": true,
      "WhatsNew": false
    },
    "Preferences": {
      "browser.rights.3.shown": true,
      "browser.rights.override": true,
      "datareporting.policy.dataSubmissionEnabled": false,
      "datareporting.policy.dataSubmissionPolicyAcceptedVersion": 9999,
      "datareporting.policy.dataSubmissionPolicyBypassNotification": true,
      "toolkit.telemetry.prompted": 2,
      "toolkit.telemetry.rejected": true
    }
  }
}
```



Troubleshouting
---------------

```sh
# No cloud-init
apt purge cloud-init -y && apt autoremove --purge -y

# If exists and fails:
systemctl disable pd-mapper.service

# If firefox should be installed via apt:
snap remove firefox

curl -o /etc/apt/keyrings/packages.mozilla.org.asc https://packages.mozilla.org/apt/repo-signing-key.gpg

echo '
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
' | sudo tee /etc/apt/sources.list.d/mozilla.sources

echo '
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
' | sudo tee /etc/apt/preferences.d/mozilla

apt update
apt install firefox
```
