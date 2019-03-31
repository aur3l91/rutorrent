#!/bin/bash -i
#
# Script d'installation ruTorrent / Nginx
# Auteur : Ex_Rat
#
# Nécessite Debian 8/9 - 64 bits & un serveur fraîchement installé
#
# Multi-utilisateurs
# Inclus VsFTPd (ftp & ftps sur le port 21), Fail2ban (avec conf nginx, ftp & ssh)
#
# Tiré du tutoriel de mondedie.fr disponible ici:
# https://mondedie.fr/d/9655-tuto-installer-rutorrent-sur-debian-9-nginx-php-fpm
#
# Merci aux traducteurs: Sophie, Spectre, Hardware, Zarev, SirGato, MiguelSam, Hierra.
#
# Installation:
#
# apt-get update && apt-get upgrade -y
# apt-get install git-core -y
#
# cd /tmp
# git clone https://github.com/exrat/rutorrent-bonobox
# cd rutorrent-bonobox
# chmod a+x bonobox.sh && ./bonobox.sh
#
# Pour gérer vos utilisateurs ultérieurement, il vous suffit de relancer le script
#
# Disclaimer
# Ce script est proposé à des fins d'expérimentation uniquement,
# le téléchargement d’oeuvre copyrightées est illégal.
#
# Merci de vous conformer à la législation en vigueur en fonction de vos pays respectifs
# en faisant vos tests sur des fichiers libres de droits.
#
# This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License


# includes
INCLUDES="includes"
# shellcheck source=/dev/null
. "$INCLUDES"/variables.sh
# shellcheck source=/dev/null
. "$INCLUDES"/langues.sh
# shellcheck source=/dev/null
. "$INCLUDES"/functions.sh

# contrôle droits utilisateur & OS
FONCCONTROL
FONCBASHRC

# contrôle installation
if [ ! -f "$NGINXENABLE"/rutorrent.conf ]; then
	# log de l'installation
	exec > >(tee "/tmp/install.log") 2>&1
	# liste users en arguments
	TESTARG=$(echo "$ARG" | tr -s ' ' '\n' | grep :)
	if [ ! -z "$TESTARG" ]; then
		echo "$ARG" | tr -s ' ' '\n' | grep : > "$ARGFILE"
	fi

	####################################
	# lancement installation ruTorrent #
	####################################

	# message d'accueil
	clear
	echo ""; set "102"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"; echo ""
	# shellcheck source=/dev/null
	. "$INCLUDES"/logo.sh

	if [ ! -s "$ARGFILE" ]; then
		echo ""
		FONCUSER # demande nom user
		echo ""
		FONCPASS # demande mot de passe
	else
		FONCARG
	fi

	PORT=5001

		# installation vsftpd
	if [ -z "$ARGFTP" ]; then
		echo ""; set "128"; FONCTXT "$1"; echo -n -e "${CGREEN}$TXT1 ${CEND}"
		read -r SERVFTP
	else
		if [ "$ARGFTP" = "ftp-off" ]; then
			SERVFTP="n"
		else
			SERVFTP="y"
		fi
	fi

	# récupération 5% root sur /home ou /home/user si présent
	FSHOME=$(df -h | grep /home | cut -c 6-9)
	if [ "$FSHOME" = "" ]; then
		echo
	else
		tune2fs -m 0 /dev/"$FSHOME" &> /dev/null
		mount -o remount /home &> /dev/null
	fi

	FONCFSUSER "$USER"

	# variable passe nginx
	PASSNGINX=${USERPWD}

	# ajout utilisateur
	useradd -M -s /bin/bash "$USER"

	# création mot de passe utilisateur
	echo "${USER}:${USERPWD}" | chpasswd

	# anti-bug /home/user déjà existant
	mkdir -p /home/"$USER"
	chown -R "$USER":"$USER" /home/"$USER"

	# variable utilisateur majuscule
	USERMAJ=$(echo "$USER" | tr "[:lower:]" "[:upper:]")

	# récupération ip serveur
	if [[ $(echo "$VERSION" "9" | awk '{print ($1 >= $2)}') == 1 ]]; then
		apt-get install -y net-tools
	fi
	FONCIP

	# récupération threads & sécu -j illimité
	THREAD=$(grep -c processor < /proc/cpuinfo)
	if [ "$THREAD" = "" ]; then
		THREAD=1
	fi

	# ajout dépôts
	# shellcheck source=/dev/null
	. "$INCLUDES"/deb.sh

	# bind9 & dhcp
	if [ ! -d /etc/bind ]; then
		rm /etc/init.d/bind9 &> /dev/null
		apt-get install -y bind9
	fi

	if [ -f /etc/dhcp/dhclient.conf ]; then
		sed -i "s/#prepend domain-name-servers 127.0.0.1;/prepend domain-name-servers 127.0.0.1;/g;" /etc/dhcp/dhclient.conf
	fi

	cp -f "$FILES"/bind/named.conf.options /etc/bind/named.conf.options

	sed -i '/127.0.0.1/d' /etc/resolv.conf # pour éviter doublon
	echo "nameserver 127.0.0.1" >> /etc/resolv.conf
	FONCSERVICE restart bind9

	# installation des paquets
	apt-get update && apt-get upgrade -y
	echo ""; set "132" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	apt-get install -y \
		htop \
		openssl \
		apt-utils \
		python \
		build-essential \
		libssl-dev \
		pkg-config \
		automake \
		libcppunit-dev \
		libtool \
		whois \
		libcurl4-openssl-dev \
		libsigc++-2.0-dev \
		libncurses5-dev \
		vim \
		nano \
		ccze \
		screen \
		subversion \
		apache2-utils \
		curl \
		"$PHPNAME" \
		"$PHPNAME"-cli \
		"$PHPNAME"-fpm \
		"$PHPNAME"-curl \
		"$PHPNAME"-geoip \
		"$PHPNAME"-json \
		unrar \
		rar \
		zip \
		mktorrent \
		fail2ban \
		ntp \
		ntpdate \
		ffmpeg \
		aptitude \
		dnsutils \
		irssi \
		libarchive-zip-perl \
		libjson-perl \
		libjson-xs-perl \
		libxml-libxslt-perl \
		libwww-perl \
		nginx \
		libmms0 \
		pastebinit \
		sox \
		libsox-fmt-mp3 \
		zlib1g-dev \
		gawk \
		libncursesw5-dev \
		psmisc
		# reserve zap xlmrpc debian 8/9
		# libxmlrpc-c++8-dev

		if [[ "$VERSION" = 8.* ]]; then
			apt-get install -y \
				libtinyxml2-2 \
				"$PHPNAME"-zip \
				libsox-fmt-all
		elif [[ "$VERSION" = 9.* ]]; then
			apt-get install -y \
				libtinyxml2-4 \
				"$PHPNAME"-xml \
				"$PHPNAME"-mbstring \
				"$PHPNAME"-readline \
				"$PHPNAME"-opcache \
				"$PHPNAME"-common \
				"$PHPNAME"-zip \
				zlib1g-dev \
				unzip \
				libsox-fmt-all
		fi

	echo ""; set "136" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# génération clé 2048 bits
	openssl dhparam -out dhparams.pem 2048 >/dev/null 2>&1 &

	# téléchargement complément favicons
	wget -T 10 -t 3 http://www.bonobox.net/script/favicon.tar.gz || wget -T 10 -t 3 http://alt.bonobox.net/favicon.tar.gz
	tar xzfv favicon.tar.gz

	# création fichiers couleurs nano
	cp -f "$FILES"/nano/ini.nanorc /usr/share/nano/ini.nanorc
	cp -f "$FILES"/nano/conf.nanorc /usr/share/nano/conf.nanorc
	cp -f "$FILES"/nano/xorg.nanorc /usr/share/nano/xorg.nanorc

	# configuration nano
	cat <<- EOF >> /etc/nanorc

		## Config Files (.ini)
		include "/usr/share/nano/ini.nanorc"

		## Config Files (.conf)
		include "/usr/share/nano/conf.nanorc"

		## Xorg.conf
		include "/usr/share/nano/xorg.nanorc"
	EOF

	echo ""; set "138" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# configuration ntp & réglage heure fr
	if [ "$GENLANG" = "fr" ]; then
		echo "Europe/Paris" > /etc/timezone
		cp -f /usr/share/zoneinfo/Europe/Paris /etc/localtime

		sed -i "s/server 0/#server 0/g;" /etc/ntp.conf
		sed -i "s/server 1/#server 1/g;" /etc/ntp.conf
		sed -i "s/server 2/#server 2/g;" /etc/ntp.conf
		sed -i "s/server 3/#server 3/g;" /etc/ntp.conf

		cat <<- EOF >> /etc/ntp.conf

			server 0.fr.pool.ntp.org
			server 1.fr.pool.ntp.org
			server 2.fr.pool.ntp.org
			server 3.fr.pool.ntp.org
		EOF

		ntpdate -d 0.fr.pool.ntp.org
	fi

	# installation xmlrpc libtorrent rtorrent
	cd /tmp || exit
	git clone https://github.com/mirror/xmlrpc-c.git

	cd xmlrpc-c/stable || exit
	./configure #--disable-cplusplus
	make -j "$THREAD"
	make install
	echo ""; set "140" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# clone rtorrent et libtorrent
	cd /tmp || exit
	git clone https://github.com/rakshasa/libtorrent.git
	git clone https://github.com/rakshasa/rtorrent.git

	# compilation libtorrent
	cd libtorrent || exit
	git checkout "$LIBTORRENT"
	git cherry-pick 7b29b6b

	# if [[ $(echo "$VERSION" "9" | awk '{print ($1 >= $2)}') == 1 ]]; then
		# cp -f "$FILES"/rutorrent/configure.ac /tmp/libtorrent/configure.ac
		# cp -f "$FILES"/rutorrent/diffie_hellman.cc /tmp/libtorrent/src/utils/diffie_hellman.cc
	# fi

	./autogen.sh
	./configure --disable-debug
	make -j "$THREAD"
	make install
	echo ""; set "142" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1 $LIBTORRENT${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# compilation rtorrent
	cd ../rtorrent || exit
	git checkout "$RTORRENT"
	./autogen.sh
	./configure --with-xmlrpc-c --with-ncurses --disable-debug
	make -j "$THREAD"
	make install
	ldconfig
	echo ""; set "144" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1 $RTORRENT${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# création des dossiers
	su "$USER" -c 'mkdir -p ~/Media ~/Other ~/Media/TV ~/Media/Movie ~/Media/Tmp/TV ~/Media/Tmp/Movie ~/Media/Done/TV ~/Media/Done/Movie ~/.session ~/.backup-session'

	# création dossier scripts perso
	mkdir "$SCRIPT"

	# création accueil serveur
	mkdir -p "$NGINXWEB"
	cp -R "$BONOBOX"/base "$NGINXBASE"

	# téléchargement et déplacement de rutorrent
	git clone https://github.com/Novik/ruTorrent.git "$RUTORRENT"
	echo ""; set "146" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# installation des plugins - thank Micdu70 ;)
	cd /tmp || exit
	git clone https://github.com/exrat/rutorrent-plugins-pack

	for PLUGINS in 'addzip' 'autodl-irssi' 'chat' 'filemanager' 'fileshare' 'geoip2' 'lbll-suite' 'logoff' 'nfo' 'pausewebui'  'ratiocolor' 'titlebar' 'trackerstatus'; do
		cp -R /tmp/rutorrent-plugins-pack/"$PLUGINS" "$RUPLUGINS"/
	done

	# configuration geoip2
	wget https://geolite.maxmind.com/download/geoip/database/GeoLite2-City.tar.gz
	tar xzfv GeoLite2-City.tar.gz
	cd /tmp/GeoLite2-City_* || exit
	mv GeoLite2-City.mmdb "$RUPLUGINS"/geoip2/database/GeoLite2-City.mmdb

	# configuration filemanager
	cp -f "$FILES"/rutorrent/filemanager.conf "$RUPLUGINS"/filemanager/conf.php

	# configuration fileshare
	cp -f "$FILES"/rutorrent/fileshare.conf "$RUPLUGINS"/fileshare/conf.php
	sed -i "s/@IP@/$IP/g;" "$RUPLUGINS"/fileshare/conf.php
	chown -R "$WDATA" "$RUPLUGINS"/fileshare
	ln -s "$RUPLUGINS"/fileshare/share.php "$NGINXBASE"/share.php

	# configuration create
	# shellcheck disable=SC2154
	sed -i "s#$useExternal = false;#$useExternal = 'mktorrent';#" "$RUPLUGINS"/create/conf.php
	# shellcheck disable=SC2154
	sed -i "s#$pathToCreatetorrent = '';#$pathToCreatetorrent = '/usr/bin/mktorrent';#" "$RUPLUGINS"/create/conf.php

	# configuration logoff
	sed -i "s/scars,user1,user2/$USER/g;" "$RUPLUGINS"/logoff/conf.php

	# configuration autodl-irssi
	cd "$RUPLUGINS" || exit
	cp -f autodl-irssi/_conf.php autodl-irssi/conf.php
	cp -f autodl-irssi/css/oblivion.min.css autodl-irssi/css/spiritofbonobo.min.css
	cp -f autodl-irssi/css/oblivion.min.css.map autodl-irssi/css/spiritofbonobo.min.css.map
	touch autodl-irssi/css/materialdesign.min.css
	FONCIRSSI "$USER" "$PORT" "$USERPWD"

	# installation mediainfo
	FONCMEDIAINFO

	# variable minutes aléatoire crontab geoip2
	MAXIMUM=58
	MINIMUM=1
	UPGEOIP=$((MINIMUM+RANDOM*(1+MAXIMUM-MINIMUM)/32767))

	cd "$SCRIPT" || exit

	for COPY in 'updateGeoIP.sh' 'backup-session.sh'
	do
		cp -f "$FILES"/scripts/"$COPY" "$SCRIPT"/"$COPY"
		chmod a+x "$COPY"
	done

	FONCBAKSESSION

	# copie favicons trackers
	cp -f /tmp/favicon/*.png "$RUPLUGINS"/tracklabels/trackers/

	# ajout thèmes
	rm -R "${RUPLUGINS:?}"/theme/themes/Blue
	cp -R "$BONOBOX"/theme/ru/Blue "$RUPLUGINS"/theme/themes/Blue
	cp -R "$BONOBOX"/theme/ru/SpiritOfBonobo "$RUPLUGINS"/theme/themes/SpiritOfBonobo
	git clone https://github.com/themightykitten/ruTorrent-MaterialDesign.git "$RUPLUGINS"/theme/themes/MaterialDesign

	# configuration thème
	sed -i "s/defaultTheme = \"\"/defaultTheme = \"SpiritOfBonobo\"/g;" "$RUPLUGINS"/theme/conf.php

	echo ""; set "148" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# liens symboliques et permissions
	ldconfig
	chown -R "$WDATA" "$RUTORRENT"
	chmod -R 777 "$RUPLUGINS"/filemanager/scripts
	chown -R "$WDATA" "$NGINXBASE"

	# configuration php
	sed -i "s/2M/10M/g;" "$PHPPATH"/fpm/php.ini
	sed -i "s/8M/10M/g;" "$PHPPATH"/fpm/php.ini
	sed -i "s/expose_php = On/expose_php = Off/g;" "$PHPPATH"/fpm/php.ini

	if [ "$GENLANG" = "fr" ]; then
		sed -i "s/^;date.timezone =/date.timezone = Europe\/Paris/g;" "$PHPPATH"/fpm/php.ini
		sed -i "s/^;date.timezone =/date.timezone = Europe\/Paris/g;" "$PHPPATH"/cli/php.ini
	else
		sed -i "s/^;date.timezone =/date.timezone = UTC/g;" "$PHPPATH"/fpm/php.ini
		sed -i "s/^;date.timezone =/date.timezone = UTC/g;" "$PHPPATH"/cli/php.ini
	fi

	sed -i "s/^;listen.owner = www-data/listen.owner = www-data/g;" "$PHPPATH"/fpm/pool.d/www.conf
	sed -i "s/^;listen.group = www-data/listen.group = www-data/g;" "$PHPPATH"/fpm/pool.d/www.conf
	sed -i "s/^;listen.mode = 0660/listen.mode = 0660/g;" "$PHPPATH"/fpm/pool.d/www.conf
	if [[ $(echo "$VERSION" "9" | awk '{print ($1 >= $2)}') == 1 ]]; then
		echo "php_admin_value[error_reporting] = E_ALL & ~E_WARNING" >> "$PHPPATH"/fpm/pool.d/www.conf
	fi

	FONCSERVICE restart "$PHPNAME"-fpm
	echo ""; set "150" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	mkdir -p "$NGINXPASS" "$NGINXSSL"
	touch "$NGINXPASS"/rutorrent_passwd
	chmod 640 "$NGINXPASS"/rutorrent_passwd

	# configuration serveur web
	mkdir "$NGINXENABLE"
	cp -f "$FILES"/nginx/nginx.conf "$NGINX"/nginx.conf
	for CONF in 'log_rutorrent.conf' 'ciphers.conf' 'cache.conf' 'php.conf'; do
		cp -f "$FILES"/nginx/"$CONF" "$NGINXCONFD"/"$CONF"
	done
	sed -i "s|@PHPSOCK@|$PHPSOCK|g;" "$NGINXCONFD"/php.conf

	cp -f "$FILES"/rutorrent/rutorrent.conf "$NGINXENABLE"/rutorrent.conf
	for VAR in "${!NGINXCONFD@}" "${!NGINXBASE@}" "${!NGINXSSL@}" "${!NGINXPASS@}" "${!NGINXWEB@}" "${!USER@}"; do
		sed -i "s|@${VAR}@|${!VAR}|g;" "$NGINXENABLE"/rutorrent.conf
	done

	if [[ $(echo "$VERSION" "9" | awk '{print ($1 >= $2)}') == 1 ]]; then
		sed -i "1i\include /etc/nginx/conf.d/log_rutorrent.conf;\n" "$NGINXENABLE"/rutorrent.conf
		sed -i "s/combined;/combined if=\$loggable;/g;" "$NGINXENABLE"/rutorrent.conf
	fi

	echo ""; set "152" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# configuration ssl
	openssl req -new -x509 -days 3658 -nodes -newkey rsa:2048 -out "$NGINXSSL"/server.crt -keyout "$NGINXSSL"/server.key <<- EOF
		KP
		North Korea
		Pyongyang
		wtf
		wtf ltd
		wtf.org
		contact@wtf.org
	EOF

	rm -R "${NGINXWEB:?}"/html &> /dev/null
	rm "$NGINXENABLE"/default &> /dev/null

	# logrotate
	cp -f "$FILES"/nginx/logrotate /etc/logrotate.d/nginx

	# configuration ssh
	sed -i "s/Subsystem[[:blank:]]sftp[[:blank:]]\/usr\/lib\/openssh\/sftp-server/Subsystem sftp internal-sftp/g;" /etc/ssh/sshd_config
	sed -i "s/UsePAM/#UsePAM/g;" /etc/ssh/sshd_config

	# chroot user
	cat <<- EOF >> /etc/ssh/sshd_config
		Match User $USER
		ChrootDirectory /home/$USER
	EOF

	# configuration .rtorrent.rc
	FONCTORRENTRC "$USER" "$PORT" "$RUTORRENT"

	# torrent welcome
	cp -f "$FILES"/rutorrent/Welcome.To.Bonobox.nfo /home/"$USER"/torrents/Welcome.To.Bonobox.nfo
	cp -f "$FILES"/rutorrent/Welcome.To.Bonobox.torrent /home/"$USER"/watch/Welcome.To.Bonobox.torrent

	# permissions
	chown -R "$USER":"$USER" /home/"$USER"
	chown root:"$USER" /home/"$USER"
	chmod 755 /home/"$USER"

	FONCSERVICE restart ssh
	echo ""; set "166" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# configuration user rutorrent.conf
	FONCRTCONF "$USERMAJ"  "$PORT" "$USER"

	# config.php
	FONCPHPCONF "$USER" "$PORT" "$USERMAJ"

	# plugins.ini
	cp -f "$FILES"/rutorrent/plugins.ini "$RUCONFUSER"/"$USER"/plugins.ini

	# script rtorrent
	FONCSCRIPTRT "$USER"
	FONCSERVICE start "$USER"-rtorrent
	FONCSERVICE start "$USER"-irssi

	# mise en place crontab
	crontab -l > rtorrentdem

	cat <<- EOF >> rtorrentdem
		$UPGEOIP 2 9 * * sh $SCRIPT/updateGeoIP.sh > /dev/null 2>&1
		0 5 * * * sh $SCRIPT/backup-session.sh > /dev/null 2>&1
	EOF

	crontab rtorrentdem
	rm rtorrentdem

	# htpasswd
	FONCHTPASSWD "$USER"

	echo ""; set "168" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""

	# configuration fail2ban
	cp -f "$FILES"/fail2ban/nginx-auth.conf /etc/fail2ban/filter.d/nginx-auth.conf
	cp -f "$FILES"/fail2ban/nginx-badbots.conf /etc/fail2ban/filter.d/nginx-badbots.conf

	cp -f /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
	sed  -i "/ssh/,+6d" /etc/fail2ban/jail.local

	cat <<- EOF >> /etc/fail2ban/jail.local

		[ssh]
		enabled  = true
		port     = ssh
		filter   = sshd
		logpath  = /var/log/auth.log
		banaction = iptables-multiport
		maxretry = 5

		[nginx-auth]
		enabled  = true
		port  = http,https
		filter   = nginx-auth
		logpath  = /var/log/nginx/*error.log
		banaction = iptables-multiport
		maxretry = 10

		[nginx-badbots]
		enabled  = true
		port  = http,https
		filter = nginx-badbots
		logpath = /var/log/nginx/*access.log
		banaction = iptables-multiport
		maxretry = 5
	EOF

	FONCSERVICE restart fail2ban

	# installation vsftpd
	if FONCYES "$SERVFTP"; then
		apt-get install -y vsftpd
		cp -f "$FILES"/vsftpd/vsftpd.conf /etc/vsftpd.conf

		# récupèration certificats nginx
		cp -f "$NGINXSSL"/server.crt  /etc/ssl/private/vsftpd.cert.pem
		cp -f "$NGINXSSL"/server.key  /etc/ssl/private/vsftpd.key.pem

		touch /etc/vsftpd.chroot_list
		touch /var/log/vsftpd.log
		chmod 600 /var/log/vsftpd.log
		FONCSERVICE restart vsftpd

		sed  -i "/vsftpd/,+10d" /etc/fail2ban/jail.local

		cat <<- EOF >> /etc/fail2ban/jail.local

			[vsftpd]
			enabled  = true
			port     = ftp,ftp-data,ftps,ftps-data
			filter   = vsftpd
			logpath  = /var/log/vsftpd.log
			banaction = iptables-multiport
			# or overwrite it in jails.local to be
			# logpath = /var/log/auth.log
			# if you want to rely on PAM failed login attempts
			# vsftpd's failregex should match both of those formats
			maxretry = 5
		EOF

		FONCSERVICE restart fail2ban
		echo ""; set "172" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""
	fi

	# déplacement clé 2048 bits
	cp -f /tmp/dhparams.pem "$NGINXSSL"/dhparams.pem
	chmod 600 "$NGINXSSL"/dhparams.pem
	FONCSERVICE restart nginx
	# contrôle clé 2048 bits
	if [ ! -f "$NGINXSSL"/dhparams.pem ]; then
		kill -HUP "$(pgrep -x openssl)"
		echo ""; set "174"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
		set "176"; FONCTXT "$1"; echo -e "${CRED}$TXT1${CEND}"; echo ""
		cd "$NGINXSSL" || exit
		openssl dhparam -out dhparams.pem 2048
		chmod 600 dhparams.pem
		FONCSERVICE restart nginx
		echo ""; set "178" "134"; FONCTXT "$1" "$2"; echo -e "${CBLUE}$TXT1${CEND}${CGREEN}$TXT2${CEND}"; echo ""
	fi

	# log users
	echo "histo-2019.log">> "$RUTORRENT"/histo-2019.log
	echo "userlog">> "$RUTORRENT"/histo-2019.log
	sed -i "s/userlog/$USER:5001/g;" "$RUTORRENT"/histo-2019.log

	set "180"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
	if [ ! -f "$ARGFILE" ]; then
		echo ""; set "182"; FONCTXT "$1"; echo -e "${CGREEN}$TXT1${CEND}"
		set "184"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND} ${CYELLOW}$USER${CEND}"
		set "186"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND} ${CYELLOW}${PASSNGINX}${CEND}"
		set "188"; FONCTXT "$1"; echo -e "${CGREEN}$TXT1${CEND}"; echo ""
	fi

	# ajout utilisateur supplémentaire
	while :; do
		if [ ! -f "$ARGFILE" ]; then
			set "190"; FONCTXT "$1"; echo -n -e "${CGREEN}$TXT1 ${CEND}"
			read -r REPONSE
		else
			if [ -s "$ARGFILE" ]; then
				REPONSE="y"
			else
				REPONSE="n"
			fi
		fi

		if FONCNO "$REPONSE"; then
			# fin d'installation
			echo ""; set "192"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
			CLEANPASS="$(grep 182 "$BONOBOX"/lang/"$GENLANG".lang | cut -c5- | sed "s/.$//")"
			sed -i "/$CLEANPASS/,+4d" /tmp/install.log
			cp -f /tmp/install.log "$RUTORRENT"/install.log
			ccze -h < "$RUTORRENT"/install.log > "$RUTORRENT"/install.html
			true > /var/log/nginx/rutorrent-error.log
			if [ -z "$ARGREBOOT" ]; then
				echo ""; set "194"; FONCTXT "$1"; echo -n -e "${CGREEN}$TXT1 ${CEND}"
				read -r REBOOT
			else
				if [ "$ARGREBOOT" = "reboot-off" ]; then
					break
				else
					reboot
					break
				fi
			fi

			if FONCNO "$REBOOT"; then
				echo ""; set "196"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
				echo -e "${CYELLOW}https://$IP/rutorrent/install.html${CEND}"
				echo ""; set "200"; FONCTXT "$1"; echo -e "${CRED}$TXT1${CEND}"
				echo ""; set "202"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
				echo -e "${CYELLOW}https://$IP/rutorrent/${CEND}"
				echo ""; echo ""; set "210"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
				echo -e "${CBLUE}                          Ex_Rat - http://mondedie.fr${CEND}"; echo ""
				break
			fi

			if FONCYES "$REBOOT"; then
				echo ""; set "196"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
				echo -e "${CYELLOW}https://$IP/rutorrent/install.html${CEND}"
				echo ""; set "202"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
				echo -e "${CYELLOW}https://$IP/rutorrent/${CEND}"
				echo ""; echo ""; set "210"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"
				echo -e "${CBLUE}                          Ex_Rat - http://mondedie.fr${CEND}"; echo ""
				reboot
				break
			fi
		fi

		if FONCYES "$REPONSE"; then
			if [ ! -s "$ARGFILE" ]; then
				echo ""
				FONCUSER # demande nom user
				echo ""
				FONCPASS # demande mot de passe
			else
				FONCARG
			fi

			# récupération 5% root sur /home/user si présent
			FONCFSUSER "$USER"

			# variable passe nginx
			PASSNGINX=${USERPWD}

			# ajout utilisateur
			useradd -M -s /bin/bash "$USER"

			# création mot de passe utilisateur
			echo "${USER}:${USERPWD}" | chpasswd

			# anti-bug /home/user déjà existant
			mkdir -p /home/"$USER"
			chown -R "$USER":"$USER" /home/"$USER"

			# variable utilisateur majuscule
			USERMAJ=$(echo "$USER" | tr "[:lower:]" "[:upper:]")

			# création de dossier
			su "$USER" -c 'mkdir -p ~/watch ~/torrents ~/.session ~/.backup-session'

			# calcul port
			FONCPORT

			# configuration .rtorrent.rc
			FONCTORRENTRC "$USER" "$PORT" "$RUTORRENT"

			# configuration user rutorrent.conf
			sed -i '$d' "$NGINXENABLE"/rutorrent.conf
			FONCRTCONF "$USERMAJ"  "$PORT" "$USER"

			# configuration script bakup .session
			FONCBAKSESSION

			# config.php
			mkdir "$RUCONFUSER"/"$USER"
			FONCPHPCONF "$USER" "$PORT" "$USERMAJ"

			# chroot user supplèmentaire
			cat <<- EOF >> /etc/ssh/sshd_config
				Match User $USER
				ChrootDirectory /home/$USER
			EOF

			FONCSERVICE restart ssh

			# plugins.ini
			cp -f "$FILES"/rutorrent/plugins.ini "$RUCONFUSER"/"$USER"/plugins.ini

			# configuration autodl-irssi
			FONCIRSSI "$USER" "$PORT" "$USERPWD"

			# permissions
			chown -R "$WDATA" "$RUTORRENT"
			chown -R "$USER":"$USER" /home/"$USER"
			chown root:"$USER" /home/"$USER"
			chmod 755 /home/"$USER"

			# script rtorrent
			FONCSCRIPTRT "$USER"
			FONCSERVICE start "$USER"-rtorrent
			FONCSERVICE start "$USER"-irssi

			# htpasswd
			FONCHTPASSWD "$USER"
			FONCSERVICE restart nginx

			# log users
			echo "userlog">> "$RUTORRENT"/histo-2019.log
			sed -i "s/userlog/$USER:$PORT/g;" "$RUTORRENT"/histo-2019.log
			if [ ! -f "$ARGFILE" ]; then
				echo ""; set "218"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND}"; echo ""
				set "182"; FONCTXT "$1"; echo -e "${CGREEN}$TXT1${CEND}"
				set "184"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND} ${CYELLOW}$USER${CEND}"
				set "186"; FONCTXT "$1"; echo -e "${CBLUE}$TXT1${CEND} ${CYELLOW}${PASSNGINX}${CEND}"
				set "188"; FONCTXT "$1"; echo -e "${CGREEN}$TXT1${CEND}"; echo ""
			fi
		fi
	done
else
	# lancement lancement gestion des utilisateurs
	chmod +x ./gestion-users.sh
	# shellcheck source=/dev/null
	source ./gestion-users.sh
fi
