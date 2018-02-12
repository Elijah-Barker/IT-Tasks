#!/bin/bash
# nano ubuntu14.04-winbind.sh; chmod 744 ubuntu14.04-winbind.sh
if [ "$USER" == root ] ;then
	echo "Yay, you are root!  I could never do it without you!";
else
	echo "Sorry "$USER", but you need to be root to run this script.";
	echo "Let's try sudo:";
	/usr/bin/sudo $0;
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

apt-get update
apt-get dist-upgrade

echo "NOTE: During krb installation (pink (or blue if on Debian) configuration screens) just press enter."
echo "Press enter to continue."
read x
apt-get install winbind samba libnss-winbind libpam-winbind libpam-krb5 krb5-locales krb5-user krb5-config sed ntp ntpdate
if [ $? == "0" ] ; then
	sleep 0;
else
	apt-get install krb5-user samba smbfs smbclient winbind sed ntp ntpdate
fi
echo "NOTE: Now it matters what you enter."

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
echo "Enter the domain controller: [ad.teamN.isucdc.com]"
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


service ntp stop
sed -i "s/server 0.ubuntu.pool.ntp.org/server `echo -e ${ADSServer}`\\nserver 0.ubuntu.pool.ntp.org/" /etc/ntp.conf
ntpdate $ADSServer
service ntp start

sed -i "1s/^/127.0.1.1	"`hostname -s`".$ADSDomain "`hostname -s`"\\n/" /etc/hosts
service hostname restart

cp /etc/samba/smb.conf /etc/samba/smb.conf.before_winbind_script
echo '[global]

workgroup = '"$ADSWorkgroup"'
password server = '"$ADSServer"'
realm = '`echo "$ADSDomain" | tr [a-z] [A-Z]`'
security = ads
idmap config * : range = 16777216-33554431
template homedir = '"$HomeDirs"'
template shell = '"$DefaultShell"'
kerberos method = secrets only
winbind use default domain = true
winbind offline logon = true

log file = /var/log/samba/log.%m
max log size = 1000
' > /etc/samba/smb.conf


echo '[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 default_ccache_name = KEYRING:persistent:%{uid}

 default_realm = '`echo "$ADSDomain" | tr [a-z] [A-Z]`'
 
[realms]

 '`echo "$ADSDomain" | tr [a-z] [A-Z]`' = {
  kdc = '"$ADSServer"'
 }

[domain_realm]
# .example.com = EXAMPLE.COM
# example.com = EXAMPLE.COM
' > /etc/krb5.conf

sed -i 's/passwd:\s\+compat\s*$/passwd:         compat winbind/g' /etc/nsswitch.conf
sed -i 's/group:\s\+compat\s*$/group:          compat winbind/g' /etc/nsswitch.conf


echo 'session    required   pam_mkhomedir.so skel=/etc/skel/ umask=0022' >> /etc/pam.d/common-account

echo "net ads join -U $AdminUser"
net ads join -U "$AdminUser"

service winbind restart
service nmbd restart
service smbd restart

echo 'Be sure to disable kerberos with <spacebar> on the next screen, then press enter.'
echo 'Press enter to continue to the next screen...'
read x

pam-auth-update

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
		service ssh restart
	fi
fi




