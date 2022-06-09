# Hardening 🌴
Debian and Arch-based Server Hardening

### Usage

-a --auto | Runs Palmtree Script 
-t --tailscale | Sets up Tailscale 
-s --ssh | Change SSH settings
-h --hardeining | Linux Hardening Config 

### Before you go ahead and run the script...

- There are a few steps in this README file that you should read for optimal setup (this really has to be done once)
- You should run this script as root or with sudo
- This guide is based of <a href="https://github.com/sunknudsen/privacy-guides/tree/master/how-to-configure-hardened-debian-server">this tutorial. </a>


  Downloading and Running the Script
```bash
  wget https://raw.githubusercontent.com/gomidee/Hardening/main/palmtree.sh
  chmod +x palmtree.sh
  sudo ./palmtree.sh
```

# Create a SSH Key Pair on your computer

### Create ssh directory

```bash
  mkdir ~/.ssh
  cd ~/.ssh
```

# Create SSH Key Pair

 ### Please change the name of you SSH Key Pair, this makes it easier if you have multiple devices/servers

```bash
  ssh-keygen -t rsa -C "MYCOOLSSHKEY"

  cat MYCOOLSSHKEY.pub
```

# Login to your server as root

```bash
  ssh root@YOURCOOLIP -i ~/.ssh/MYCOOLSSHKEY
  ```

# Disable bash history

```bash
  echo "HISTFILESIZE=0" >> ~/.bashrc
  source ~/.bashrc
```

# Create a password for root
  
  ```bash
  passwd
  
 ```
  # Type you cool and strong password :)

# Add a user

```bash

  adduser cool-guy
  
  ```

# Copy root authorized_keys to your user home directory

# IF YOUR USER IS SOMETHING OTHER THEN 'cool-guy' PLEASE CHANGE 'cool-guy' to your user name

```bash
  mkdir /home/cool-guy/.ssh
  cp /root/.ssh/authorized_keys /home/cool-guy/.ssh/authorized_keys
  chown -R cool-guy:cool-guy /home/cool-guy/.ssh
```
# Exit 

```bash
  exit
```

# Login as cool-guy

```bash
  ssh cool-guy@YOUCOOLIP -i ~/.ssh/MYCOOLSSHKEY
  ```

# IF THAT WORKED, YOU'RE PRETTY MUCH GOOD 2 GO

## Switch to root

```bash
  su -
  ```

type your cool and strong password

# Disable root login and password authentication

```bash
  sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh
  ```

# Run the following as root

```bash
  apt update
  apt upgrade -y
  ```

# Good to go, enjoy!
