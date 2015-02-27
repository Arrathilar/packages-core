
err() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    RED="${BOLD}\e[1;31m"
	local mesg=$1; shift
	printf "${RED}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

msg() {
    ALL_OFF="\e[1;0m"
    BOLD="\e[1;1m"
    GREEN="${BOLD}\e[1;32m"
	local mesg=$1; shift
	printf "${GREEN}==>${ALL_OFF}${BOLD} ${mesg}${ALL_OFF}\n" "$@" >&2
}

check_pkgs()
{
	local remove=""

    for pkg in ${packages} ; do
        for rmpkg in $(pacman -Qq | grep ${pkg}) ; do
            if [ "${pkg}" == "${rmpkg}" ] ; then
               removepkgs="${removepkgs} ${rmpkg}"
            fi
        done
    done

    packages="${removepkgs}"
}

detectDE()
{
    if [ x"$KDE_FULL_SESSION" = x"true" ]; then DE=kde;
    elif [ x"$GNOME_DESKTOP_SESSION_ID" != x"" ]; then DE=gnome;
    elif `dbus-send --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus.GetNameOwner string:org.gnome.SessionManager > /dev/null 2>&1` ; then DE=gnome;
    elif xprop -root _DT_SAVE_MODE 2> /dev/null | grep ' = \"xfce4\"$' >/dev/null 2>&1; then DE=xfce;
    elif [ x"$DESKTOP_SESSION" = x"LXDE" ]; then DE=lxde;
    else DE=""
    fi
}

post_upgrade() {
	
	# steam replacement
	pacman -Qq steam &> /tmp/cmd1
	pacman -Qq steam-native &> /tmp/cmd2
	if [[ "$(grep 'steam' /tmp/cmd1)" == "steam" && "$(grep 'steam-native' /tmp/cmd2)" == "steam-native" ]]; then
		msg "Replacing steam and steam-native with steam-manjaro ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rdd steam steam-native
		pacman --noconfirm -S steam-manjaro
	fi        
	if [[ "$(grep 'steam' /tmp/cmd1)" == "steam" && "$(grep 'steam-native' /tmp/cmd2)" == *"not"* ]]; then
		msg "Replacing steam with steam-manjaro ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rdd steam
		pacman --noconfirm -S steam-manjaro
	fi
	
	# dropbox returns to normal
	pacman -Qq dropbox3 &> /tmp/cmd1
	pacman -Qq dropbox2 &> /tmp/cmd2
	if [ "$(grep 'dropbox3' /tmp/cmd1)" == "dropbox3" ]; then
		msg "Replacing dropbox3 with dropbox ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rdd dropbox3
		pacman --noconfirm -S dropbox
	fi
	if [ "$(grep 'dropbox2' /tmp/cmd2)" == "dropbox2" ]; then
		msg "Replacing dropbox2 with dropbox ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rdd dropbox2
		pacman --noconfirm -S dropbox
	fi

	# update rob's signature
	if [ "$(vercmp $2 20150204-1)" -lt 0 ]; then
		msg "Update Rob's signature ..."
		# running dirmngr helps prevent pacman-key from failing to connect to servers
		dirmngr </dev/null
		pacman-key --refresh-keys 5C0102A6
	fi

	# get anex's signature
	if [ "$(vercmp $2 20141220-1)" -lt 0 ]; then
		msg "Get anex's signature ..."
		pacman-key -r A80EBF3E
		pacman-key --lsign-key A80EBF3E
	fi

	# recreate pacman gnupg master key
	if [ "$(vercmp $2 20141210-1)" -lt 0 ]; then
		pacman -Qq haveged &> /tmp/cmd1
		if [ "$(grep 'haveged' /tmp/cmd1)" != "haveged" ]; then
			msg "Installing haveged"
			rm /var/lib/pacman/db.lck &> /dev/null
			if [[ -d /run/systemd ]];then
				pacman --noconfirm -S haveged
			else
				pacman --noconfirm -S haveged-openrc
			fi
		fi
		msg "Recreate pacman gnupg master key ..."
		if [[ -d /run/systemd ]];then
			systemctl start haveged
		else
			rc-service haveged start
		fi
		rm -fr /etc/pacman.d/gnupg
		pacman-key --init
		pacman -Ss fontconfig-infinality-ultimate | grep bundle &> /tmp/cmd2
		if [[ -n "$(cat /tmp/cmd2)" ]]; then
			msg "Signing infinality keys"
			pacman-key -r 962DDE58
			pacman-key --lsign-key 962DDE58
		fi
		msg "Populate Archlinux and Manjaro gnupg keys ..."
		pacman-key --populate archlinux manjaro
	fi

	# get artoo's new signature
	if [ "$(vercmp $2 20141206-1)" -lt 0 ]; then
		msg "Get new artoo's signature ..."
		pacman-key -r B35859F8
		pacman-key --lsign-key B35859F8
	fi
	
	# fix cups service name for cups 2.0
	if [ "$(vercmp $2 20141120-1)" -lt 0 ]; then
		if [ -h "/etc/systemd/system/multi-user.target.wants/cups.service" ]; then
			msg "Updating CUPS service name ..."
			rm /etc/systemd/system/multi-user.target.wants/cups.service
			ln -sf /usr/lib/systemd/system/org.cups.cupsd.service /etc/systemd/system/multi-user.target.wants/org.cups.cupsd.service
		fi
	fi

	# fix artoo's signature
	if [ "$(vercmp $2 20141014-1)" -lt 0 ]; then
		msg "Get artoo's signature ..."
		pacman-key -r 5DCB998E
		pacman-key --lsign-key 5DCB998E
	fi
	
	# fix java-runtime-common replaces java-common (https://www.archlinux.org/news/java-users-manual-intervention-required-before-upgrade/)
	if [ "$(vercmp $2 20141013-1)" -lt 0 ]; then
		pacman -Qq java-common &> /tmp/cmd1
		if [ "$(grep 'java-common' /tmp/cmd1)" == "java-common" ]; then
			msg "Replacing java-common with java-runtime-common ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			archlinux-java unset
			pacman --noconfirm -Rdd java-common
			pacman --noconfirm -Sdd --asdeps java-runtime-common
			archlinux-java fix
		fi
	fi

	# fix kirek's signature
	if [ "$(vercmp $2 20141002-1)" -lt 0 ]; then
		msg "Get kirek's signature ..."
		pacman-key -r AC97B894
		pacman-key --lsign-key AC97B894
	fi

	# nvidia legacy changes (sept-oct 2014 - kernels 3.10-3.17)
	pacman -Qq nvidia-utils &> /tmp/cmd1
	pacman -Qq mhwd-nvidia-340xx &> /tmp/cmd2
	if [ "$(grep 'nvidia-utils' /tmp/cmd1)" == "nvidia-utils" ]; then
		if [ "$(grep 'mhwd-nvidia-340xx' /tmp/cmd2)" != "mhwd-nvidia-340xx" ]; then
			msg "Updating mhwd database"
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -S mhwd-db
		fi
		mhwd | grep " video-nvidia " &> /tmp/cmd3
		mhwd-gpu | grep nvidia &> /tmp/cmd4
		pacman -Qq | grep nvidia | grep -v mhwd | grep -v toolkit &> /tmp/cmd5
		if [[ -z "$(cat /tmp/cmd3)" && -n "$(cat /tmp/cmd4)" ]]; then
			msg "Maintaining video driver at version nvidia-340xx"
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -Rdd $(cat /tmp/cmd5)
			pacman --noconfirm -S $(cat /tmp/cmd5 | sed 's|nvidia|nvidia-340xx|g')
			rm -r /var/lib/mhwd/local/pci/video-nvidia/
			cp -a /var/lib/mhwd/db/pci/graphic_drivers/nvidia-340xx/ /var/lib/mhwd/local/pci/
		fi
	fi

	# fix ayceman's signature
	if [ "$(vercmp $2 20140918-1)" -lt 0 ]; then
		msg "Get ayceman's signature ..."
		pacman-key -r 604F8BA2
		pacman-key --lsign-key 604F8BA2
		sed -i -e s'|^.*SyncFirst.*|SyncFirst   = manjaro-system|g' /etc/pacman.conf
	fi
	
	# fix kwallet
	pacman -Qq kdeutils-kwallet &> /tmp/cmd1
	if [ "$(grep 'kdeutils-kwallet' /tmp/cmd1)" == "kdeutils-kwallet" ]; then
		msg "Replacing kdeutils-kwallet with kdeutils-kwalletmanager ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rdd kdeutils-kwallet
		pacman --noconfirm -S kdeutils-kwalletmanager
	fi
	
	
	# fix twisted
	pacman -Qq twisted &> /tmp/cmd1
	pacman -Q twisted &> /tmp/cmd2
	if [ "$(grep 'twisted' /tmp/cmd1)" == "twisted" ]; then
		if [ "$(cat /tmp/cmd2 | cut -d" " -f2 | sed -e 's/\.//g' | sed -e 's/\-//g')" -lt "14001" ]; then
			msg "Fix twisted ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			rm -f /usr/lib/python2.7/site-packages/twisted/plugins/dropin.cache
			pacman --noconfirm -S python2-twisted
		fi
	fi

	# fix terminus-font
	pacman -Qq terminus-font &> /tmp/cmd1
	pacman -Q terminus-font &> /tmp/cmd2
	if [ "$(grep 'terminus-font' /tmp/cmd1)" == "terminus-font" ]; then
		if [ "$(cat /tmp/cmd2 | cut -d" " -f2 | sed -e 's/\.//g' | sed -e 's/\-//g')" -lt "4385" ]; then
			msg "Fix terminus-font ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			rm /etc/fonts/conf.d/75-yes-terminus.conf &> /dev/null
			pacman --noconfirm -S terminus-font
		fi
	fi

	# fix btrfs-progs
	pacman -Qq btrfs-progs &> /tmp/cmd1
	pacman -Q btrfs-progs &> /tmp/cmd2
	if [ "$(grep 'btrfs-progs' /tmp/cmd1)" == "btrfs-progs" ]; then
		if [ "$(cat /tmp/cmd2 | cut -d" " -f2 | sed -e 's/\.//g' | sed -e 's/\-//g')" -lt "3141" ]; then
			msg "Fix btrfs-progs ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			rm /usr/bin/fsck.btrfs &> /dev/null
			pacman --noconfirm -S btrfs-progs
		fi
	fi

	# fix python-configobj downgrade
	pacman -Qq python-configobj &> /tmp/cmd1
	if [ "$(vercmp $2 20140407-1)" -lt 0 ]; then
		if [ "$(grep 'python-configobj' /tmp/cmd1)" == "python-configobj" ]; then
			msg "Fix python-configobj ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			pacman --noconfirm -S python-configobj
		fi
	fi

	# fix freeimage
	pacman -Qq freeimage &> /tmp/cmd1
	pacman -Q freeimage &> /tmp/cmd2
	if [ "$(grep 'freeimage' /tmp/cmd1)" == "freeimage" ]; then
		if [ "$(cat /tmp/cmd2 | cut -d" " -f2 | sed -e 's/\.//g' | sed -e 's/\-//g')" -lt "31602" ]; then
			msg "Fix freeimage ..."
			rm /var/lib/pacman/db.lck &> /dev/null
			rm /usr/lib/libfreeimageplus.so.3
			pacman --noconfirm -S freeimage
		fi
	fi
	# fix dcells signature
	if [ "$(vercmp $2 20140525-1)" -lt 0 ]; then
		msg "Get dcells signature ..."
		pacman-key -r 5C0102A6
		pacman-key --lsign-key 5C0102A6
	fi

	# xorg downgrade
	if [ "$(vercmp $2 20140221-1)" -lt 0 ]; then
		msg "Prepare for Xorg-Server downgrade ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm --force -Suu
	        # check for xorg-server
	        pacman -Qq xorg-server &> /tmp/cmd1
		if [ "$(grep 'xorg-server' /tmp/cmd1)" != "xorg-server" ]; then
			msg "Installing missing Xorg-Server ..."
			pacman --noconfirm -S xorg-server
		fi
	fi

	# workaround for catalyst-server removal
	pacman -Qq catalyst-server &> /tmp/cmd1
	pacman -Q catalyst-utils &> /tmp/cmd2
	packages="catalyst-server catalyst-input catalyst-video"
	conflicts="xf86-input-acecad xf86-input-aiptek xf86-input-evdev xf86-input-joystick xf86-input-keyboard xf86-input-mouse xf86-input-synaptics xf86-input-void xf86-input-wacom xorg-server-common xorg-server"
	if [ "$(grep 'catalyst-server' /tmp/cmd1)" == "catalyst-server" ]; then
	   if [ "$(cat /tmp/cmd2 | cut -d- -f2 | cut -d" " -f2 | sed -e 's/\.//g')" -lt "13351005" ]; then
	      msg "Preparing Catalyst installation ..."
	      rm /var/lib/pacman/db.lck &> /dev/null
	      check_pkgs
	      pacman --noconfirm -Rdd ${packages} &> /dev/null
	      pacman --noconfirm -S ${conflicts} &> /dev/null
	   fi
	fi

	# fix korrodes signature
	if [ "$(vercmp $2 20140212-1)" -lt 0 ]; then
		msg "Get korrodes signature ..."
		pacman-key -r 5C0102A6
		pacman-key --lsign-key 5C0102A6
	fi

	# remove pyc-files if python-dbus < 1.2.0-2
	pacman -Qq python-dbus &> /tmp/cmd1
	pacman -Q python-dbus &> /tmp/cmd2
	if [ "$(grep 'python-dbus' /tmp/cmd1)" == "python-dbus" ]; then
	   if [ "$(cat /tmp/cmd2 | cut -d" " -f2 | sed -e 's/\.//g' | sed -e 's/\-//g')" -lt "1202" ]; then
		msg "Prepare python-dbus update ..."
		# System operation
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/_compat.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/_dbus.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/_expat_introspect_parser.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/_version.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/bus.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/connection.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/decorators.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/exceptions.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/gi_service.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/glib.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/lowlevel.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/proxies.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/server.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/service.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/__pycache__/types.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/mainloop/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/dbus/mainloop/__pycache__/glib.cpython-33.pyc
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm --force -Sdd python-dbus &> /dev/null
	   fi
	fi

	# fix mdm-themes on systems
	pacman -Qq mdm-themes &> /tmp/cmd1
	packages="mdm-themes-extra"
	if [ "$(vercmp $2 20131206-1)" -lt 0 ] && [ "$(grep 'mdm-themes' /tmp/cmd1)" == "mdm-themes" ]; then
		msg "Fixing mdm-themes issue ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -S ${packages} &> /dev/null
	fi

	# remove pyc-files if python-gobject < 3.10.1
	pacman -Qq python-gobject &> /tmp/cmd1
	pacman -Q python-gobject &> /tmp/cmd2
	if [ "$(grep 'python-gobject' /tmp/cmd1)" == "python-gobject" ]; then
	   if [ "$(cat /tmp/cmd2 | cut -d- -f2 | cut -d" " -f2 | sed -e 's/\.//g')" -lt "3101" ]; then
		msg "Fixing python-gobject ..."
		# System operation
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/__init__.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/docstring.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/docstring.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/importer.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/importer.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/module.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/module.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/pygtkcompat.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/pygtkcompat.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/types.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/__pycache__/types.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/_glib/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/_glib/__pycache__/__init__.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/_glib/__pycache__/option.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/_glib/__pycache__/option.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/__init__.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/constants.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/constants.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/propertyhelper.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/propertyhelper.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/signalhelper.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/_gobject/__pycache__/signalhelper.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/GIMarshallingTests.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/GIMarshallingTests.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/GLib.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/GLib.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/GObject.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/GObject.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Gdk.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Gdk.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Gio.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Gio.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Gtk.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Gtk.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Pango.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/Pango.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/__init__.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/keysyms.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/overrides/__pycache__/keysyms.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/gi/repository/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/gi/repository/__pycache__/__init__.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/pygtkcompat/__pycache__/__init__.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/pygtkcompat/__pycache__/__init__.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/pygtkcompat/__pycache__/generictreemodel.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/pygtkcompat/__pycache__/generictreemodel.cpython-33.pyo
		rm -f /usr/lib/python3.3/site-packages/pygtkcompat/__pycache__/pygtkcompat.cpython-33.pyc
		rm -f /usr/lib/python3.3/site-packages/pygtkcompat/__pycache__/pygtkcompat.cpython-33.pyo
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm --force -Sdd python-gobject &> /dev/null
	   fi
	fi

	# depreciate sysctl.conf
	if [ "$(vercmp $2 20130921-1)" -lt 0 ] && [ -f /etc/sysctl.conf ]; then
		msg "Depreciate sysctl.conf ..."
		if [ -f /etc/sysctl.d/99-sysctl.conf ]; then
			mv /etc/sysctl.d/99-sysctl.conf /etc/sysctl.d/99-sysctl.conf.pacsave
		fi
		mv /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf
	fi

	# fix pamac on systems without Gnome session
        detectDE
	pacman -Qq pamac &> /tmp/cmd1
	packages="lxpolkit"
	if [ "$(vercmp $2 20130905-1)" -lt 0 ] && [ "$DE" != "gnome" ] && [ "$(grep 'pamac' /tmp/cmd1)" == "pamac" ]; then
		msg "Fixing polkit issue in pamac ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -S ${packages} &> /dev/null
	fi

	# depreciate linux39
	pacman -Qq linux39 &> /tmp/cmd1
	pacman -Qq linux310 &> /tmp/cmd2
	packages=$(pacman -Qqs linux39 | sed s'|linux39|linux310|'g)
	if [ "$(vercmp $2 20130829-1)" -lt 0 ] && [ "$(grep 'linux39' /tmp/cmd1)" == "linux39" ]; then
		msg "Depreciating linux39 ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rscn linux39 &> /dev/null
		if [ "$(grep 'linux310' /tmp/cmd2)" == "linux310" ]; then
			msg "linux310 found, skipping installation ..."
		else
			msg "Installing linux310 ..."
			pacman --noconfirm -S ${packages} &> /dev/null
		fi
	fi

	# workaround to install octopi 0.2.0
	pacman -Qq octopi &> /tmp/cmd1
	pacman -Q octopi &> /tmp/cmd2
	packages="octopi octopi-notifier"
	if [ "$(vercmp $2 20130824-1)" -lt 0 ] && [ "$(grep 'octopi' /tmp/cmd1)" == "octopi" ]; then
	   if [ "$(cat /tmp/cmd2 | cut -d- -f1 | cut -d"." -f4)" -lt "0825" ]; then
		msg "Updating octopi ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		check_pkgs
		pacman --noconfirm -S ${packages} &> /dev/null
	   fi
	fi

	# workaround for bug: http://bugs.manjaro.org/index.php?do=details&task_id=124
	pacman -Qq bluez4 &> /tmp/cmd1
	pacman -Qq bluez &> /tmp/cmd2
	pacman -Q bluez &> /tmp/cmd3
	if [ "$(vercmp $2 20130820-4)" -lt 0 ] && [ "$(grep 'bluez4' /tmp/cmd1)" != "bluez4" ] && [ "$(grep 'bluez' /tmp/cmd2)" == "bluez" ]; then
	   if [ "$(cat /tmp/cmd3 | cut -d. -f1 | cut -d" " -f2)" -lt "5" ]; then
		msg "Fixing bluez ..."
		rm /var/lib/pacman/db.lck &> /dev/null
		pacman --noconfirm -Rdd bluez &> /dev/null
		pacman --noconfirm -S bluez4 bluez-libs &> /dev/null
	   fi
	fi

	# Update filesystem to /usr/bin
	if [ "$(vercmp $2 20130606-1)" -lt 0 ] && [ ! -L "/bin" ] && [ ! -L "/sbin" ] && [ ! -L "/usr/sbin" ]; then
		msg "Binaries move to /usr/bin ..."
		msg "Please be patient."
		local files="$(find /bin/ /sbin/ /usr/sbin/ | tr "\n" " ")"

		# List unowned files
		for file in $files
		do
			local filename="${file##*/}"
			if [ "${filename}" == "" ]; then continue; fi

			pacman -Qo "${file}" &>/dev/null
			if [ $? -ne 0 ]; then msg "Moving unowned file '${file}' to '/usr/bin'"; fi
		done

		# Update database
		local pkgs="$(pacman -Qqo /bin /sbin /usr/sbin | sort -u | tr "\n" " ")"
		for pkg in ${pkgs}
		do
			if [ "${pkg}" == "filesystem" ]; then continue; fi
			local path="/var/lib/pacman/local/$(pacman -Q ${pkg} | sed 's/ /-/g')/files"
			if [ ! -f "${path}" ]; then continue; fi

			sed -i -e 's|^bin/|usr/bin/|' -e 's|^sbin/|usr/bin/|' -e 's|^usr/sbin/|usr/bin/|' -e 's|^bin$|usr/bin|' -e 's|^sbin$|usr/bin|' -e 's|^usr/sbin$|usr/bin|' "${path}"
		done

		# Move files
		for file in $files
		do
			local filename="${file##*/}"
			if [ "${filename}" == "" ]; then continue; fi

			# Check if file is a symlink
			if [ -L "${file}" ]; then
				local filelink="$(readlink "${file}")"

				# Check if destination file exists. Otherwise move the symlink.
				if [ -e "/usr/bin/${filename}" ]; then
					# Remove link
					unlink "${file}"
				elif [[ "${file}" =~ ^"/bin/".*|^"/sbin/".* ]] && [[ "${filelink}" =~ ^"../usr/bin/".* ]]; then
					# Move link to /usr/bin and update relative path
					filelink="$(echo "${filelink}" | sed 's|^\.\./usr/bin/||')"
					ln -s "${filelink}" "/usr/bin/${filename}"
					unlink "${file}"
				elif [[ "${file}" =~ ^"/bin/".*|^"/sbin/".* ]] && [[ "${filelink}" =~ ^"../".* ]]; then
					# Move link to /usr/bin and update relative path
					filelink="$(echo "${filelink}" | sed 's|^\.\./|\.\./\.\./|')"
					ln -s "${filelink}" "/usr/bin/${filename}"
					unlink "${file}"
				elif [[ "${file}" =~ ^"/usr/sbin/".* ]] && [[ "${filelink}" =~ ^"../bin/".* ]]; then
					# Move link to /usr/bin and update relative path
					filelink="$(echo "${filelink}" | sed 's|^\.\./bin/||')"
					ln -s "${filelink}" "/usr/bin/${filename}"
					unlink "${file}"
				else
					# Move link as it is
					ln -s "${filelink}" "/usr/bin/${filename}"
					unlink "${file}"
				fi
			else
				if [ -L "/usr/bin/${filename}" ]; then
					unlink "/usr/bin/${filename}"
					mv "${file}" "/usr/bin/"
				elif [ -e "/usr/bin/${filename}" ]; then
					err "'/usr/bin/${filename}' already exists! Moving file to '/usr/bin_duplicates/${filename}'"
					if [ ! -d "/usr/bin_duplicates" ]; then mkdir "/usr/bin_duplicates"; fi
					mv "${file}" "/usr/bin_duplicates/"
				else
					mv "${file}" "/usr/bin/"
				fi
			fi
		done

		# Fix /usr/bin/init symlink
		ln -sf "../lib/systemd/systemd" "/usr/bin/init"

		# filesystem should own /bin, /sbin and /usr/sbin
		local filesystem_path="/var/lib/pacman/local/$(pacman -Q filesystem | sed 's/ /-/g')/files"
		sed -i 's|^\%FILES\%|\%FILES\%\nbin\nsbin\nusr/sbin|' "${filesystem_path}"

		# Remove directories and create symlinks
		rm -fr /bin
		rm -fr /sbin
		rm -fr /usr/sbin
		ln -s usr/bin /bin
		ln -s usr/bin /sbin
		ln -s bin /usr/sbin

		msg "Now update your system."
	fi

	# Remove obsolete version file of manjaro-system
	if [ -f /var/lib/manjaro-system/version ]; then
		rm /var/lib/manjaro-system/version
	fi
}
