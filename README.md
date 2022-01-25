# Hardening
Debian/Ubuntu Server Hardening

EASY RUN
  
```bash
  wget <RAWFILE>
  chmod +x <FILENAME>
  sudo ./<FILENAME>
```

Hey, just a little notice

• This script is written for Debian/Ubuntu but it may work on other Linux flavours
• Read before you run
• This script is designed for servers

  #Create a SSH Key Pair on your computer

#Create ssh directory, you probablly know what to do...

```bash
  mkdir ~/.ssh
  cd ~/.ssh
```

#Create SSH Key Pair

 #Please change the name of you SSH Key Pair, this makes it easier if you have multiple devices/servers

```bash
  ssh-keygen -t rsa -C "MYCOOLSSHKEY"

  cat MYCOOLSSHKEY.pub
```

#Login to your server as root

```bash
  ssh root@YOURCOOLIP -i ~/.ssh/MYCOOLSSHKEY
  ```

#Disable bash history

```bash
  echo "HISTFILESIZE=0" >> ~/.bashrc
  source ~/.bashrc
```

#Create a password for root
  
  ```bash
  passwd
  
 ```
  #Type you cool and strong password :)

#Add a user

```bash

  adduser cool-guy
  
  ```

#Copy root authorized_keys to your user home directory

#IF YOUR USER IS SOMETHING OTHER THEN 'cool-guy' PLEASE CHANGE 'cool-guy' to your user name

```bash
  mkdir /home/cool-guy/.ssh
  cp /root/.ssh/authorized_keys /home/cool-guy/.ssh/authorized_keys
  chown -R cool-guy:cool-guy /home/cool-guy/.ssh
```
#Exit 

```bash
  exit
```

#Login as cool-guy

```bash
  ssh cool-guy@YOUCOOLIP -i ~/.ssh/MYCOOLSSHKEY
  ```

#IF THAT WORKED, YOU'RE PRETTY MUCH GOOD 2 GO

#Switch to root

```bash
  su -
  ```

  #type your cool and strong password

#Disable root login and password authentication

```bash
  sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh
  ```

#Run the following as root

```bash
  apt update
  apt upgrade -y
  ```

#If your server has sudo enabled, you can exit root and run the script as your user, if not run the script as 'su'

#PLEASE, READ THE SCRIPT BEFORE YOU EXECUTE IT, I TAKE NO RESPONSABILITY OVER ANY DAMANGES OR UNWANTED CONFIG CHANGES TO YOUR SERVER (although I use this script myself)

HAVE AN AWESOME DAY! :)
