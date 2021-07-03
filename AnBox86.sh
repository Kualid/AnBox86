#!/bin/bash

### AnBox86.sh
# Authors: lowspecman420, WheezyE
#
# This script is made to be run by the Termux app (for Android devices).  It is recommended you download Termux from F-Droid rather than from the Google Play Store.
# This script will install a PRoot guest system (Ubuntu 20.04) in Termux.  Then it will install box86 and wine-i386 on that guest system.
# Note that this script uses tabs (	) instead of spaces ( ) for formatting since parts of this script use heredoc (i.e. eom & eot).
#

function run_Main()
{
	# Update Termux source lists (just in case Termux was downloaded from Google Play Store instead of from F-Droid)
	#  - Termux source list mirrors are located here: https://github.com/termux/termux-app#google-playstore-deprecated
	echo "deb https://termux.mentality.rip/termux-main stable main" > $PREFIX/etc/apt/sources.list 
	echo "deb https://termux.mentality.rip/termux-games games stable" > $PREFIX/etc/apt/sources.list.d/game.list
	echo "deb https://termux.mentality.rip/termux-science science stable" > $PREFIX/etc/apt/sources.list.d/science.list
	apt update && apt upgrade -y -o Dpkg::Options::=--force-confnew # upgrade Termux and suppress user prompts
	
	apt install proot-distro git -y # Create the Ubuntu PRoot within Termux
	linux32 proot-distro install ubuntu-20.04
	git clone https://github.com/ZhymabekRoman/proot-static
	# initialize paths for our shell instance and also add them to bashrc for future shell instances
	export PATH=$HOME/proot-static/bin:$PATH && echo >> ~/.bashrc "export PATH=$HOME/proot-static/bin:$PATH"
	export PROOT_LOADER=$HOME/proot-static/bin/loader && echo >> ~/.bashrc "export PROOT_LOADER=$HOME/proot-static/bin/loader"
	
	run_InjectSecondStageInstaller # Commands are injected into Ubuntu. None of the commands injected here will be run yet. We will run them upon logging in as root.
	
	echo >> launch_ubuntu.sh "#!/bin/bash" # Create a script to log in as the 'user' account, which we will create later
	echo >> launch_ubuntu.sh ""
	echo >> launch_ubuntu.sh "proot-distro login ubuntu-20.04 -- su - user"
	chmod +x launch_ubuntu.sh
	
	echo -e "\nUbunutu PRoot guest system installed. Launching PRoot. . ."
	
	proot-distro login ubuntu-20.04 # Log into the Ubuntu PRoot as 'root'.
	
	# The second stage installer script is auto-run after logging into the Ubuntu PRoot as 'root'.
	# The second stage script installs box86 & Wine.
}



# ----------------
function run_InjectSecondStageInstaller() # Creates a script that will set up Ubuntu during first login of 'root'
{
	# Inject the second stage script into the Ubuntu guest system
	cat > $PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu-20.04/etc/profile.d/AnBox86b.sh <<- EOM
		#!/bin/bash
		
		# Second stage script self-destruct
		#  - This setup script should only be run once.
		#  - Because this script is located within /etc/profile.d/ bash will auto-run it upon any login ('root' or 'user').
		#  - When bash loads this script, it will first load all the below commands into memory, then execute them.
		#  - Thus, upon first login of 'root' or 'user', bash will load these commands into memory, delete this very script, then run the rest of the commands.
		rm /etc/profile.d/AnBox86b.sh
		
		# Second stage installer script
		echo -e "\nPRoot launch successful.  Now installing box86 and wine on Ubuntu PRoot. . ."
		
		apt update -y
		
		export LANGUAGE='C' && echo >> ~/.bashrc "export LANGUAGE='C'"
		export LC_ALL='C' && echo >> ~/.bashrc "export LC_ALL='C'"
		export DISPLAY=localhost:0 && echo >> ~/.bashrc "export DISPLAY=localhost:0"
		
		adduser --disabled-password --gecos "" user # Make a user account named 'user' without prompting us for information
		apt install sudo -y && echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers # Give the 'user' account sudo access
		
		# Create a user account within Ubuntu to install Wine into.  Best practices are to not run Wine as root.
		#  - We are currently in Ubuntu's 'root'.  To run commands within the Ubuntu 'user' account, we must push them into 'user' using heredoc/eot.
		sudo su - user <<"EOT"
			export LANGUAGE='C' && echo >> ~/.bashrc "export LANGUAGE='C'"
			export LC_ALL='C' && echo >> ~/.bashrc "export LC_ALL='C'"
			export DISPLAY=localhost:0 && echo >> ~/.bashrc "export DISPLAY=localhost:0"
			
			# Install a Python3(?) dependency without prompts - since prompts will freeze our eot commands
			export DEBIAN_FRONTEND=noninteractive
			ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
			sudo apt-get install -y tzdata
			sudo dpkg-reconfigure --frontend noninteractive tzdata
			
			# Build and install Box86
			sudo apt install git cmake python3 build-essential gcc -y # Box86 dependencies
			git clone https://github.com/ptitSeb/box86
			sh -c "cd box86 && cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo ~/box86 && make && make install"
			
			# Install Wine
			sudo apt install wget -y
			sudo apt install libxinerama1 libfontconfig1 libxrender1 libxcomposite-dev libxi6 libxcursor-dev libxrandr2 -y # for wine on proot
			wget https://twisteros.com/wine.tgz
			tar -xvzf wine.tgz
			
			sudo apt install xserver-xephyr -y
			echo >> launch_wine.sh "#!/bin/bash"
			echo >> launch_wine.sh ""
			echo >> launch_wine.sh "export DISPLAY=localhost:0"
			echo >> launch_wine.sh "sudo Xephyr :1 -fullscreen &"
			echo >> launch_wine.sh "DISPLAY=:1 box86 ~/wine/bin/wine explorer /desktop=wine,1280x720 explorer"
			sudo chmod +x launch_wine.sh
			
			echo -e "\nInstallation complete."
			echo " - From Termux, you can use launch_ubuntu.sh to start Ubuntu PRoot."
			echo " - From Ubuntu, you can use launch_wine.sh to start box86 & wine.  Make sure the XServer XSDL Android app is running."
			echo "    (we are currently in a user account within Ubuntu)"
		EOT
		# The above commands were pushed into the 'user' account while we were in 'root'. So now that these commands are done, we will still be in 'root'.
		# Let's tell bash to log into the 'user' account as our final action.
		sudo su - user
	EOM
	# The above commands will be run in the future upon login to Ubuntu PRoot as 'root' ('user' doesn't exist yet).
}

run_Main
