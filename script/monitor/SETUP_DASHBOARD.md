
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
apt install xdotool
apt install dbus-x11
```



### 3.) Create a kiosk user with home-directory.

```sh
useradd -m kiosk
```

and disable Welocme-Screen
```sh
echo "yes" > /home/kiosk/.config/gnome-initial-setup-done
```



### 4.) Edit following file `nano /etc/gdm3/custom.conf` to turn of wayland and turn on autologin for user 'kiosk'.

```
[daemon]
# Uncomment the line below to force the login screen to use Xorg
#WaylandEnable=false

WaylandEnable=false

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



### 6.) Create custom service to start firefox loading the page.

Therefore create a file `/etc/systemd/system/kiosk.service` with this content:

```
[Unit]
Description=Firefox Kiosk
Wants=graphical.target
After=graphical.target

[Service]
Environment=DISPLAY=:0
# Set firefox language, needs 'apt install language-pack-gnome-de' 
Environment=LANG=de_DE.UTF-8
Type=simple
# Always a fresh firefox ('-' allow error if common does not exist)
ExecStartPre=-/usr/bin/rm -r /home/kiosk/snap/firefox/common
# Move Mouse (should also work on small screens), needs 'apt install dbus-x11'
ExecStartPre=/usr/bin/xdotool mousemove 4096 2160
# See: https://wiki.mozilla.org/Firefox/CommandLineOptions (just -kiosk URL => Start-Assistant, so use -url too)
ExecStart=/usr/bin/firefox -fullscreen -kiosk -url http://monitor.example.net/check.html
Restart=always
RestartSec=30
User=kiosk
Group=kiosk

[Install]
WantedBy=graphical.target
```



### 7.) Enable the service and reboot

```sh
systemctl enable kiosk
reboot
```



Troubleshouting
---------------

```
systemctl disable pd-mapper.service
apt purge cloud-init -y && apt autoremove --purge -y
```
