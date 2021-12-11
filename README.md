# Hardening
Debian/Ubuntu Server Hardening

EASY RUN
  
```bash
  wget https://raw.githubusercontent.com/gomidee/Hardening/main/palmtree.sh?token=AVNJBY5J3M4UKHVKKM32R5LBWQICK
  chmod +x palmtree.sh
  sudo ./palmtree.sh
```

Hey, just a little notice

• This script is written for Debian/Ubuntu but it may work on other Linux flavours
• Please, I highly recommend following these steps manually for optimal results

#Creating a VPS

  #Create a SSH Key Pair on your computer

#Create ssh directory, you probablly know what to do...

  mkdir ~/.ssh
  cd ~/.ssh

#Create SSH Key Pair

 #Please change the name of you SSH Key Pair, this makes it easier if you have multiple devices/servers

  ssh-keygen -t rsa -C "MYCOOLSSHKEY"

  cat MYCOOLSSHKEY.pub


#Login to your server as root

  ssh root@YOURCOOLIP -i ~/.ssh/MYCOOLSSHKEY

#Disable bash history

  echo "HISTFILESIZE=0" >> ~/.bashrc
  source ~/.bashrc

#Create a password for root
  
  passwd
  #Type you cool and strong password :)

#Add a user

  adduser cool-guy

#Copy root authorized_keys to your user home directory

#IF YOUR USER IS SOMETHING OTHER THEN 'cool-guy' PLEASE CHANGE 'cool-guy' to your user name

  mkdir /home/cool-guy/.ssh
  cp /root/.ssh/authorized_keys /home/cool-guy/.ssh/authorized_keys
  chown -R cool-guy:cool-guy /home/cool-guy/.ssh

#Exit 

  exit

#Login as cool-guy

  ssh cool-guy@YOUCOOLIP -i ~/.ssh/MYCOOLSSHKEY

#IF THAT WORKED, YOU'RE PRETTY MUCH GOOD 2 GO

#Switch to root

  su -

  #type your cool and strong password

#Disable root login and password authentication

  sed -i -E 's/^(#)?PermitRootLogin (prohibit-password|yes)/PermitRootLogin no/' /etc/ssh/sshd_config
  sed -i -E 's/^(#)?PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
  systemctl restart ssh

#Run the following as root

  apt update
  apt upgrade -y

#If your server has sudo enabled, you can exit root and run the script as your user, if not run the script as 'su'

#PLEASE, ALWAYS READ SCRIPTS YOU EXECUTE FROM STRANGERS, READ IT BEFORE YOU RUN IT, I'M NOT RESPONSIBLE FOR ANYTHING THAT MAY HAPPEN AS A RESULT OF THIS SCRIPT (although everything should be fine, I personally use it for all my servers and stuff)

HAVE AN AWESOME DAY! :)
