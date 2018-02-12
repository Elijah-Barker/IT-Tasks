#!/bin/bash
# nano centos7-winbind.sh; chmod 744 centos7-winbind.sh
if [ "$USER" == root ] ;then
	echo "Yay, you are root!  I could never do it without you!";
else
	echo "Sorry "$USER", but you need to be root to run this script.";
	echo "Let's try sudo:";
	sudo $0;
	exit;
fi

echo "Have you:";
echo "1.  pointed this server's primary DNS to your AD server?";
echo "2.  synchronized this server's time with that of your AD server?";
echo "3.  configured your hostname.domain.name in /etc/hosts after 127.0.1.1?";
echo "4.  applied the latest updates?";
echo "5.  taken a snapshot?";
echo "Do you want to continue? [y/N]";
read continue;
if [ "$continue" == "y" ] ;then
	sleep 0;
else
	if [ "$continue" == "Y" ] ;then
		sleep 0;
	else
		exit 0;
	fi
fi

rm -f $0

yum upgrade
yum install samba-common samba-winbind samba-winbind-clients ntp ntpdate
chkconfig ntpd on
systemctl enable ntpd

echo "Enter the NetBIOS domain (Workgroup): [TEAMN]"
read ADSWorkgroup
if [ "$ADSWorkgroup" == "" ] ;then
	ADSWorkgroup="TEAMN"
fi
echo "Enter the AD domain: [teamN.isucdc.com]"
read ADSDomain
if [ "$ADSDomain" == "" ] ;then
	ADSDomain="teamN.isucdc.com"
fi
echo "Enter the list of domain controllers separated by spaces: [ad.teamN.isucdc.com]"
read ADSServer
if [ "$ADSServer" == "" ] ;then
	ADSServer="ad.teamN.isucdc.com"
fi
echo "Enter the name of the domain admin: [Administrator]"
read AdminUser
if [ "$AdminUser" == "" ] ;then
	AdminUser="Administrator"
fi
echo "Enter the location of the home directories: [/home/%U]"
read HomeDirs
if [ "$HomeDirs" == "" ] ;then
	HomeDirs="/home/%U"
fi
echo "Enter the default shell for users: [/bin/bash]"
read DefaultShell
if [ "$DefaultShell" == "" ] ;then
	DefaultShell="/bin/bash"
fi
echo "Enter the domain-wide sudoers group: [sudoers]"
read Sudoers
if [ "$Sudoers" == "" ] ;then
	Sudoers="sudoers"
fi
echo "Enter the domain-wide ssh users: [sshers]"
read Sshers
if [ "$Sshers" == "" ] ;then
	Sshers="sshers"
fi
echo "Do you want to continue? [y/N]";
read continue;
if [ "$continue" == "y" ] ;then
	sleep 0;
else
	if [ "$continue" == "Y" ] ;then
		sleep 0;
	else
		exit 0;
	fi
fi

service ntpd stop
sed -i "s/server 0.rhel.pool.ntp.org/server `echo -e ${ADSServer}`\\nserver 0.rhel.pool.ntp.org/" /etc/ntp.conf
ntpdate $ADSServer
service ntpd start

sed -i "1s/^/127.0.1.1	"`hostname -s`".$ADSDomain "`hostname -s`"\\n/" /etc/hosts

authconfig \
--update \
--kickstart \
--enablewinbind \
--enablewinbindauth \
--smbsecurity=ads \
--smbworkgroup="$ADSWorkgroup" \
--smbrealm="$ADSDomain" \
--smbservers="$ADSServer" \
--winbindjoin="$AdminUser" \
--winbindtemplatehomedir="$HomeDirs" \
--winbindtemplateshell="$DefaultShell" \
--enablemkhomedir \
--enablewinbindoffline \
--enablewinbindusedefaultdomain \
--enablelocauthorize

echo "Add sudoers ability and ssh restrictions? [Y/n]"
read continue;
if [ "$continue" == "n" ] ;then
	sleep 0;
else
	if [ "$continue" == "N" ] ;then
		sleep 0;
	else
		echo "%${Sudoers}	ALL=(ALL:ALL) ALL" >> /etc/sudoers
		echo "AllowGroups ${Sshers}" >> /etc/ssh/sshd_config
		service sshd restart
	fi
fi

echo "Do you want to reboot now? [y/N]";
read continue;
if [ "$continue" == "y" ] ;then
	sleep 0;
else
	if [ "$continue" == "Y" ] ;then
		sleep 0;
	else
		exit 0;
	fi
fi
reboot

exit 0

# service winbind restart
# service nmbd restart
# service smbd restart

