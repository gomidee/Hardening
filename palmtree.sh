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

apt update
apt upgrade -y
apt install ufw vim wget curl wget

#Setting up Tailscale

echo "Would you like to intall Tailscale? [Y,n]"
read input
if [[ $input == "Y" || $input == "y" ]]; then

        curl -fsSL https://tailscale.com/install.sh | sh

        echo "Would you like to set this as an exit node? [Y, n]"
	   read input
	   if [[ $input == "Y" || $input == "y" ]]; then

		   #Allow IP Fowarding

		echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.conf
                echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.conf
                sysctl -p /etc/sysctl.conf

                  #Add UFW allow rules
		  ufw allow 41641/udp
		  ufw allow in on tailscale0 

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
                ufw default deny incoming
		ufw default allow outgoing

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
sysctl -w net.ipv4.icmp_echo_ignore_all=1

cp /etc/ufw/before.rules /etc/ufw/before.rules.backup
rm /etc/ufw/before.rules

cat << "EOF" >> /etc/ufw/before.rules
#
# rules.before
#
# Rules that should be run before the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward
#

# Don't delete these required lines, otherwise there will be errors
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]
# End required lines


# allow all on loopback
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-output -o lo -j ACCEPT

# quickly process packets for which we already have a connection
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# drop INVALID packets (logs these in loglevel medium and higher)
-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
-A ufw-before-input -m conntrack --ctstate INVALID -j DROP

# ok icmp codes for INPUT
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT

# ok icmp code for FORWARD
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT

# allow dhcp client to work
-A ufw-before-input -p udp --sport 67 --dport 68 -j ACCEPT

#
# ufw-not-local
#
-A ufw-before-input -j ufw-not-local

# if LOCAL, RETURN
-A ufw-not-local -m addrtype --dst-type LOCAL -j RETURN

# if MULTICAST, RETURN
-A ufw-not-local -m addrtype --dst-type MULTICAST -j RETURN

# if BROADCAST, RETURN
-A ufw-not-local -m addrtype --dst-type BROADCAST -j RETURN

# all other non-local packets are dropped
-A ufw-not-local -m limit --limit 3/min --limit-burst 10 -j ufw-logging-deny
-A ufw-not-local -j DROP

# allow MULTICAST mDNS for service discovery (be sure the MULTICAST line above
# is uncommented)
-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT

# allow MULTICAST UPnP for service discovery (be sure the MULTICAST line above
# is uncommented)
-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

# don't delete the 'COMMIT' line or these rules won't be processed
COMMIT
EOF

cp /etc/sysctl.conf /etc/sysctl.conf.backup
cat << "EOF" >> /etc/sysctl.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl -p

ufw reload

#To unblock ping requests, use following command
  # sysctl -w net.ipv4.icmp_echo_ignore_all=0

#Change default SSH Port

  echo "Would you like to change your default ssh port? (highly recommended) [Y, n]"
  read input
    if [[ $input == "y" || $input == "Y" ]]; then
    
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
	    echo "Which port would you like to use?"
	    
	    read port1
	    
cat << "EOF" >> /etc/ufw/before.rules.backup
	    
	    #	$OpenBSD: sshd_config,v 1.100 2016/08/15 12:32:04 naddy Exp $

# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# This sshd was compiled with PATH=/usr/bin:/bin:/usr/sbin:/sbin

# The strategy used for options in the default sshd_config shipped with
# OpenSSH is to specify options with their default value where
# possible, but leave them commented.  Uncommented options override the
# default value.

Port port1
AddressFamily inet
#ListenAddress 0.0.0.0
#ListenAddress ::

#HostKey /etc/ssh/ssh_host_rsa_key
#HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and keying
#RekeyLimit default none

# Logging
#SyslogFacility AUTH
#LogLevel INFO

# Authentication:

#LoginGraceTime 2m
PermitRootLogin no
#StrictModes yes
#MaxAuthTries 6
#MaxSessions 10

#PubkeyAuthentication yes

# Expect .ssh/authorized_keys2 to be disregarded by default in future.
#AuthorizedKeysFile	.ssh/authorized_keys .ssh/authorized_keys2

#AuthorizedPrincipalsFile none

#AuthorizedKeysCommand none
#AuthorizedKeysCommandUser nobody

# For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
#HostbasedAuthentication no
# Change to yes if you don't trust ~/.ssh/known_hosts for
# HostbasedAuthentication
#IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
#IgnoreRhosts yes

# To disable tunneled clear text passwords, change to no here!
PasswordAuthentication no
PermitEmptyPasswords no

# Change to yes to enable challenge-response passwords (beware issues with
# some PAM modules and threads)
ChallengeResponseAuthentication no

# Kerberos options
#KerberosAuthentication no
#KerberosOrLocalPasswd yes
#KerberosTicketCleanup yes
#KerberosGetAFSToken no

# GSSAPI options
#GSSAPIAuthentication no
#GSSAPICleanupCredentials yes
#GSSAPIStrictAcceptorCheck yes
#GSSAPIKeyExchange no

# Set this to 'yes' to enable PAM authentication, account processing,
# and session processing. If this is enabled, PAM authentication will
# be allowed through the ChallengeResponseAuthentication and
# PasswordAuthentication.  Depending on your PAM configuration,
# PAM authentication via ChallengeResponseAuthentication may bypass
# the setting of "PermitRootLogin without-password".
# If you just want the PAM account and session checks to run without
# PAM authentication, then enable this but set PasswordAuthentication
# and ChallengeResponseAuthentication to 'no'.
UsePAM yes

#AllowAgentForwarding yes
#AllowTcpForwarding yes
#GatewayPorts no
X11Forwarding yes
#X11DisplayOffset 10
#X11UseLocalhost yes
#PermitTTY yes
PrintMotd no
#PrintLastLog yes
#TCPKeepAlive yes
#UseLogin no
#UsePrivilegeSeparation sandbox
#PermitUserEnvironment no
#Compression delayed
#ClientAliveInterval 0
#ClientAliveCountMax 3
#UseDNS no
#PidFile /var/run/sshd.pid
#MaxStartups 10:30:100
#PermitTunnel no
#ChrootDirectory none
#VersionAddendum none

# no default banner path
#Banner none

# Allow client to pass locale environment variables
AcceptEnv LANG LC_*

# override default of no subsystems
Subsystem	sftp	/usr/lib/openssh/sftp-server

# Example of overriding settings on a per-user basis
#Match User anoncvs
#	X11Forwarding no
#	AllowTcpForwarding no
#	PermitTTY no
#	ForceCommand cvs server
EOF

	    
	   
	    
	    
	    
	    
	    

 echo "Would you like to restart your system? (highly recommended) [Y, n]"
 read input
   if [[ $input == "Y" || $input == "y" ]]; then

	   reboot
else 
	echo "Cool, enjoy your day!"

fi


#END
