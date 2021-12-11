#!/bin/bash
  #11/12/2021
  #Scallop
  #Debian/Ubuntu Server Hardening
  
#Please Excecute this script with sudo permissions of as 'su'

  echo "Are you ready? [Y,n]"
  read input
  if [[ $input == "Y" || $input == "y" ]]; then
	  echo "Let's Go!"

  else
         exit	  
  fi

  #Disable bash history and update/upgrade packages

sed -i -E 's/^HISTSIZE=/#HISTSIZE=/' ~/.bashrc
sed -i -E 's/^HISTFILESIZE=/#HISTFILESIZE=/' ~/.bashrc
echo "HISTFILESIZE=0" >> ~/.bashrc
source ~/.bashrc

sudo apt update
sudo apt upgrade -y
sudo apt install ufw vim wget curl wget

#Setting up Tailscale

echo "Would you like to intall Tailscale? [Y,n]"
read input
if [[ $input == "Y" || $input == "y" ]]; then

        curl -fsSL https://tailscale.com/install.sh | sh

        echo "Would you like to set this as an exit node? [Y, n]"
	   read input
	   if [[ $input == "Y" || $input == "y" ]]; then

		   #Allow IP Fowarding

		echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
                echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
                sudo sysctl -p /etc/sysctl.conf

                  #Add UFW allow rules
		  sudo ufw allow 41641/udp
		  sudo ufw allow in on tailscale0 

		  #Advertise as Exit Node

                tailscale up --advertise-exit-node

		
	else
		echo "Sweet... No exit node"

        fi

else
        echo "Cool..."
fi

#Setting up UFW

echo "Would you like to setup UFW? [Y, n]"
read input
  if [[ $input == "Y" || $input == "y" ]]; then
                
                #Default Rules
                sudo ufw default deny incoming
		sudo ufw default allow outgoing

		echo "OK"

		echo "Please type 10 ports you would like to open (PLEASE INCLUDE YOUR SSH PORT 'default is 22')"
                read rule1 rule2 rule3 rule4 rule5 rule6 rule7 rule8 rule9 rule10

                ufw allow $rule1
                ufw allow $rule2
                ufw allow $rule3
                ufw allow $rule4
                ufw allow $rule5
                ufw allow $rule6
                ufw allow $rule7
                ufw allow $rule8
                ufw allow $rule9
                ufw allow $rule10
		ufw enable

	else

     echo "PLEASE MAKE SURE TO SETUP A FIREWALL LATER"

  fi

  #Block ping requests
sudo sysctl -w net.ipv4.icmp_echo_ignore_all=1

#To unblock ping requests, use following command
  #sudo sysctl -w net.ipv4.icmp_echo_ignore_all=0

#Change default SSH Port

  echo "Would you like to change your default ssh port? (highly recommended) [Y, n]"
  read input
    if [[ $input == "y" || $input == "Y" ]]; then
	    echo "Follow these setps manually"


	    echo "To connect to your server via SSH through your new port type -p NEWSSHPORT at the end of the ssh cool-guy@MYCOOLIP"
	    echo "add your new ssh port to ufw by using $ ufw allow NEWSSHPORT"
	    echo "edit your ssh port $ vi /etc/ssh/sshd_config"
	    echo "change 22 to your desired port, if line is commented, please uncomment it by removing the #"
	    echo "run the following command $ service ssh restart"

  else
       echo "No Worries!"

  fi

 echo "Would you like to restart your system? (highly recommended) [Y, n]"
 read input
   if [[ $input == "Y" || $input == "y" ]]; then

	   reboot
else 
	echo "Cool, enjoy your day!"

fi


#END
