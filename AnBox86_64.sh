#!/bin/bash

### AnBox86_64.sh
# Authors: lowspecman420, WheezyE
# Special thanks: michalbednarski, xeffyr, ZhymabekRoman, ptitSeb
#
# This script is made to be run by the Termux app (for Android devices).  It is recommended you download Termux from F-Droid rather than from the Google Play Store.
# This script will install a PRoot guest system (Debian) in Termux.  Then it will install box86 and wine-i386 on that guest system.
# Note that this script uses tabs (	) instead of spaces ( ) for formatting since parts of this script use heredoc (i.e. eom & eot).
#

function run_Main()
{
	rm AnBox86_64.sh 2>/dev/null # self-destruct (since this script should only be run once)
	
	# Enable left & right keys in Termux (optional) - https://www.learntermux.tech/2020/01/how-to-enable-extra-keys-in-termux.html
	mkdir $HOME/.termux/ 2>/dev/null
	echo "extra-keys = [['ESC','/','-','HOME','UP','END'],['TAB','CTRL','ALT','LEFT','DOWN','RIGHT']]" >> $HOME/.termux/termux.properties
	termux-reload-settings
	
	# Update Termux source lists (just in case Termux was downloaded from Google Play Store instead of from F-Droid)
	#  - Termux source list mirrors are located here: https://github.com/termux/termux-app#google-playstore-deprecated
	echo "deb https://termux.mentality.rip/termux-main stable main" > $PREFIX/etc/apt/sources.list 
	echo "deb https://termux.mentality.rip/termux-games games stable" > $PREFIX/etc/apt/sources.list.d/game.list
	echo "deb https://termux.mentality.rip/termux-science science stable" > $PREFIX/etc/apt/sources.list.d/science.list
	pkg update -y -o Dpkg::Options::=--force-confnew && apt upgrade -y -o Dpkg::Options::=--force-confnew # upgrade Termux and suppress user prompts
	
	# Create the Debian PRoot within Termux
	pkg install proot proot-distro git -y # F-Droid termux crashes with apt install proot-distro
	proot-distro install debian
	
	# Create a script to log into PRoot as the 'user' account (which we will create later)
	echo >> launch_anbox86-64.sh "#!/bin/bash"
	echo >> launch_anbox86-64.sh ""
	echo >> launch_anbox86-64.sh "proot-distro login --bind /system/ --bind /data/data/com.termux/files/usr/bin --bind /data/data/com.termux/files/usr/libexec/termux-am --isolated --shared-tmp debian -- su - user" # '--isolated' avoids program conflicts between Termux & PRoot (credits: Mipster)
	chmod +x launch_anbox86-64.sh
	
	# Inject a 'second stage' installer script into Debian
	# - This script will not be run right now.  It will be auto-run upon first login (since it is located within '/etc/profile.d/').
	run_InjectSecondStageInstaller
	
	# Log into PRoot (which will then launch the 'second stage' installer)
	echo -e "\nDebian PRoot guest system installed. Launching Debian PRoot and continuing installation. . ."
	proot-distro login --bind /system/ --bind /data/data/com.termux/files/usr/bin --bind /data/data/com.termux/files/usr/libexec/termux-am --isolated --shared-tmp debian # Log into the Debian PRoot as 'root'. Enable binds to launch Android apps. Isolate for wine
}

# ---------------

function run_InjectSecondStageInstaller()
{
	# Inject the 'second stage' installer script into the Debian guest system to be run laterb (none of this gets run right now)
	cat > $PREFIX/var/lib/proot-distro/installed-rootfs/debian/etc/profile.d/AnBox64b.sh <<- 'EOM'
		#!/bin/bash
		# Second stage installer script
		#  - Because this script is located within '/etc/profile.d/', bash will auto-run it upon any login into PRoot ('root' or 'user').
		echo -e "\nPRoot launch successful.  Now installing Box86/Box64 and Wine/Wine64 on Debian PRoot. . ."
		
		# Script self-destruct (since this setup script should only be run once)
		#  - Upon first PRoot login, bash will load these commands into memory, delete this script file, then run the rest of the commands.
		rm /etc/profile.d/AnBox64b.sh
		
		apt update -y
		
		# Create a user account within PRoot & install Wine into it (best practices are to not run Wine as root).
		#  - We are currently in PRoot's 'root'.  To run commands within a 'user' account, we must push them into 'user' using heredoc.
		adduser --disabled-password --gecos "" user # Make a user account named 'user' without prompting us for information
		apt install sudo -y && echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers # Give the 'user' account sudo access
		sudo su - user <<- 'EOT'
			sudo dpkg --add-architecture armhf && sudo apt update #enable multi-arch on aarch64 (so we can install armhf libraries for box86/winei386)
			
			# Compile box64 & box86 on-device (takes a long time, builds are fresh and links less breakable)
				## Install a Python3(?) dependency (a box86_64 compiling dependency) without prompts (prompts will freeze our 'eot' commands)
				#export DEBIAN_FRONTEND=noninteractive
				#ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime
				#sudo apt-get install -y tzdata
				#sudo dpkg-reconfigure --frontend noninteractive tzdata

				## Build and install box64
				#sudo apt install git cmake python3 build-essential gcc -y # box64 dependencies
				#git clone https://github.com/ptitSeb/box64
				#sh -c "cd box64 && mkdir build; cd build; cmake .. -DARM_DYNAREC=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo; make && make install"
				#sudo rm -rf box64

				## Build and install box86 (for aarch64)
				#sudo apt install gcc-arm-linux-gnueabihf git cmake python3 build-essential gcc -y
				#git clone https://github.com/ptitSeb/box86
				#sh -c "cd box86 && mkdir build; cd build; cmake .. -DARM_DYNAREC=ON -DRPI4ARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo; make && make install"
				#sudo rm -rf box86

			# Download and install box64 & box86 (fast, but builds can be old and links could break)
				# RPi4ARM64 builds for box64 & box86 seem to work on AArch64 Termux Debian PRoot
				# Box86/box64 binaries are from GitHub "Actions" build artifacts, linked to via www.nightly.link
				# TODO: Add error checking and compile is link is broken
				sudo apt install p7zip-full wget git -y
				wget https://nightly.link/ptitSeb/box64/actions/artifacts/148608519.zip #box64 (RPI4ARM64)
				wget https://nightly.link/ptitSeb/box86/actions/artifacts/148607181.zip #box86 (RPI4ARM64)
				7z x 148608519.zip -o"/usr/local/bin/" #extract box64 to /usr/local/bin/box64
				7z x 148607181.zip -o"/usr/local/bin/" #extract box86 to /usr/local/bin/box86
				sudo chmod +x /usr/local/bin/box64 /usr/local/bin/box86 #make the extracted files executable
				# Also install extra box86 i386 & box64 x86_64 libraries
				git clone https://github.com/ptitSeb/box64.git; mkdir -p /usr/lib/x86_64-linux-gnu/ && cp box64/x64lib/* /usr/lib/x86_64-linux-gnu/
				git clone https://github.com/ptitSeb/box86.git; mkdir -p /usr/lib/i386-linux-gnu/ && cp box86/x86lib/* /usr/lib/i386-linux-gnu/
				rm -rf box64/ box86/ 148608519.zip 148607181.zip
			
			# Install amd64-wine (64-bit) and i386-wine (32-bit)
			#TODO: Go through this dependencies list and weed out un-needed libraries.
				# libc6:armhf is needed for box86 to be detected by aarch64 https://github.com/ptitSeb/box86/issues/465
				# Unsure about the rest but wine-amd64 & wine-i386 on aarch64 need some libs too.
				# Credits: monkaBlyat (Dr. van RockPi), Itai-Nelken, & WheezyE
			sudo apt install apt-utils libcups2 libfontconfig1 libncurses6 libxcomposite-dev libxcursor-dev libxi6 libxinerama1 libxrandr2 libxrender1 -y # for wine64
			sudo apt install libavcodec58:armhf libavformat58:armhf libboost-filesystem1.74.0:armhf libboost-iostreams1.74.0:armhf \
				libboost-program-options1.74.0:armhf libc6:armhf libcal3d12v5:armhf libcups2:armhf libcurl4:armhf libfontconfig1:armhf \
				libfreetype6:armhf libgdk-pixbuf2.0-0:armhf libgl1-mesa-dev:armhf libgtk2.0-0:armhf libjpeg62:armhf libmpg123-0:armhf \
				libmyguiengine3debian1v5:armhf libncurses5:armhf libncurses6:armhf libopenal1:armhf libpng16-16:armhf \
				libsdl1.2-dev:armhf libsdl2-2.0-0:armhf libsdl2-image-2.0-0:armhf libsdl2-mixer-2.0-0:armhf libsdl2-net-2.0-0:armhf \
				libsdl-mixer1.2:armhf libsmpeg0:armhf libsnappy1v5:armhf libstdc++6:armhf libswscale5:armhf libudev1:armhf \
				libvorbis-dev:armhf libx11-6:armhf libx11-dev:armhf libxcb1:armhf libxcomposite1:armhf libxcursor1:armhf libxext6:armhf \
				libxi6:armhf libxinerama1:armhf libxrandr2:armhf libxrender1:armhf libxxf86vm1:armhf mesa-va-drivers:armhf osspd:armhf \
				pulseaudio:armhf -y # for wine on aarch64 (multiarch)
			sudo apt install libasound2:armhf libpulse0:armhf libxml2:armhf libxslt1.1:armhf libxslt1-dev:armhf -y # fixes wine sound
			sudo apt install libpulse0 -y # not sure if needed, but can't hurt anything
			
			mkdir downloads; cd downloads
				# Wine download links from WineHQ: https://dl.winehq.org/wine-builds/
				# TODO: Update wine to 6.0 or higher - check box86 compatability
				LNK1="https://dl.winehq.org/wine-builds/debian/dists/bullseye/main/binary-amd64/"
				DEB1="wine-stable-amd64_5.0.0~bullseye_amd64.deb" #wine64 supporting files
					#DEB1="wine-stable-amd64_6.0.2~bullseye-1_amd64.deb"
				DEB2="wine-stable_5.0.0~bullseye_amd64.deb" #wine64 main binary file
					#DEB2="wine-stable_6.0.2~bullseye-1_amd64.deb"
				#DEB3="winehq-stable_5.0.0~bullseye_amd64.deb" #mostly contains desktop shortcuts and docs?
				LNK2="https://dl.winehq.org/wine-builds/debian/dists/bullseye/main/binary-i386/"
				DEB4="wine-stable-i386_5.0.0~bullseye_i386.deb" #wine main binary file
					#DEB4="wine-stable-i386_6.0.2~bullseye-1_i386.deb"
				#DEB5="wine-stable_5.0.0~bullseye_i386.deb" #wine supporting files - CONFLICTS WITH wine64 supporting files
				#DEB6="winehq-stable_5.0.0~bullseye_i386.deb" #mostly contains desktop shortcuts and docs?
					
				# Download, extract wine, and install wine
				echo "Downloading wine . . ."
				wget ${LNK1}${DEB1} || echo "${DEB1} download failed!"
				wget ${LNK1}${DEB2} || echo "${DEB2} download failed!"
				#wget ${LNK1}${DEB3} || echo "${DEB3} download failed!"
				wget ${LNK2}${DEB4} || echo "${DEB4} download failed!"
				#wget ${LNK2}${DEB5} || echo "${DEB5} download failed!"
				#wget ${LNK2}${DEB6} || echo "${DEB6} download failed!"
				echo "Extracting wine . . ."
				dpkg-deb -x ${DEB1} wine-installer
				dpkg-deb -x ${DEB2} wine-installer
				#dpkg-deb -x ${DEB3} wine-installer
				dpkg-deb -x ${DEB4} wine-installer
				#dpkg-deb -x ${DEB5} wine-installer
				#dpkg-deb -x ${DEB6} wine-installer
				echo "Installing wine . . ."
				mv wine-installer/opt/wine* ~/wine
			cd ..; rm -rf downloads/
			
			# Give PRoot an X server ('screen 1') to send video to (and don't stop the X server after last client logs off)
			sudo apt install xserver-xephyr -y
			echo -e >> ~/.bashrc "\n# Initialize X server every time user logs in"
			echo >> ~/.bashrc "export DISPLAY=localhost:0"
			echo >> ~/.bashrc "sudo Xephyr :1 -noreset -fullscreen &"
			echo >> ~/.bashrc ""
			
			# Make scripts and symlinks to transparently run wine with box86 (since we don't have binfmt_misc available)
			# TODO: These wine/wine64 launcher scripts cause winetricks to fail - no workaround found (if/then statements don't work either)
			# TODO: Create an alternative to binfmt on Termux using scripts (Termux does not support binfmt)			
			echo -e '#!/bin/bash' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '# Launch the XServer XSDL Android app ("&" continue running more commands)' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '#  - This step requires proot-distro to be started with some Termux directories bound' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e 'am start --user 0 -n x.org.server/x.org.server.RunFromOtherApp &' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '# Initialize X server on screen 1 ("&" continue running more commands)' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '#  - Note that envvar PULSE_SERVER is not needed (like XServer XSDL suggests) because Termux uses its own Pulseaudio package' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e 'DISPLAY=localhost:0 sudo Xephyr :1 -noreset -fullscreen &' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '# When this wine script is called, launch wine desktop with box64 and pass arguments to wine (then wait for wine session to finish)' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '# - TODO: find a way to detect device resolution and put that into here as a variable' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e "#DISPLAY=:1 box64 $HOME/wine/bin/wine64 explorer /desktop=wine,1920x1200" '"$@"' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e "DISPLAY=:1 box64 $HOME/wine/bin/wine64" '"$@"' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e '# When the wine session is finished, switch back to the Termux Android app' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			echo -e 'am start --user 0 -n com.termux/com.termux.app.TermuxActivity' | sudo tee -a /usr/local/bin/wine64 >/dev/null
			
			echo -e '#!/bin/bash' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '# Launch the XServer XSDL Android app ("&" continue running more commands)' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '#  - This step requires proot-distro to be started with some Termux directories bound' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e 'am start --user 0 -n x.org.server/x.org.server.RunFromOtherApp &' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '# Initialize X server on screen 1 ("&" continue running more commands)' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '#  - Note that envvar PULSE_SERVER is not needed (like XServer XSDL suggests) because Termux uses its own Pulseaudio package' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e 'DISPLAY=localhost:0 sudo Xephyr :1 -noreset -fullscreen &' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '# When this wine script is called, launch wine desktop with box86 and pass arguments to wine (then wait for wine session to finish)' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '# - TODO: find a way to detect device resolution and put that into here as a variable' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e "#DISPLAY=:1 WINEARCH=win32 box86 $HOME/wine/bin/wine explorer /desktop=wine,1920x1200" '"$@"' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e "DISPLAY=:1 WINEARCH=win32 box86 $HOME/wine/bin/wine" '"$@"' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e '# When the wine session is finished, switch back to the Termux Android app' | sudo tee -a /usr/local/bin/wine >/dev/null
			echo -e 'am start --user 0 -n com.termux/com.termux.app.TermuxActivity' | sudo tee -a /usr/local/bin/wine >/dev/null
			
			echo -e '#!/bin/bash'"\nbox64 $HOME/wine/bin/wineserver" '"$@"' | sudo tee -a /usr/local/bin/wineserver >/dev/null
				#sudo ln -s $HOME/wine/bin/wine64 /usr/local/bin/wine64
				#sudo ln -s $HOME/wine/bin/wine /usr/local/bin/wine
				#sudo ln -s $HOME/wine/bin/wineserver /usr/local/bin/wineserver
			sudo ln -s $HOME/wine/bin/wineboot /usr/local/bin/wineboot
			sudo ln -s $HOME/wine/bin/winecfg /usr/local/bin/winecfg
			sudo chmod +x /usr/local/bin/wine64 /usr/local/bin/wine /usr/local/bin/wineboot /usr/local/bin/winecfg /usr/local/bin/wineserver
			
			# Install winetricks
			sudo apt-get install wget unzip cabextract -y # winetricks needs these
			wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks # download
			sudo chmod +x winetricks
			sudo mv winetricks /usr/local/bin
			
			# Download small x86/x64 programs for testing (optional)
				#Download notepad++ 32bit and 64bit to test
				sudo apt install p7zip-full nano -y
				wget https://notepad-plus-plus.org/repository/7.x/7.0/npp.7.bin.zip #32bit
				wget https://notepad-plus-plus.org/repository/7.x/7.0/npp.7.bin.x64.zip #64bit
				7z x npp.7.bin.zip -o"npp32" && rm npp.7.bin.zip
				#DISPLAY=:1 WINEPREFIX=~/.wine32/ /usr/local/bin/box86 /home/user/wine/bin/wine /home/user/npp32/notepad++.exe
				7z x npp.7.bin.x64.zip -o"npp64" && rm npp.7.bin.x64.zip
				#DISPLAY=:1 /usr/local/bin/box64 /home/user/wine/bin/wine64 /home/user/npp64/notepad++.exe
				
				#Download the EarthSiege 2 Demo
				# NOTE: Users must be in the same directory as ES.EXE when they run it with wine (or else the game will crash)
				wget https://archive.org/download/es2demo/es2demo.exe #32bit
				7z x es2demo.exe -o"EarthSiegeDemo" && rm es2demo.exe
				7z x EarthSiegeDemo/DATA.EXE -o"EarthSiegeDemo" && rm EarthSiegeDemo/DATA.EXE
				#DISPLAY=:1 WINEPREFIX=~/.wine32/ /usr/local/bin/box86 /home/user/wine/bin/wine /home/user/ES.EXE
			
			# Display instructions whenever logging into proot
			echo "Cyan=$'\e[1;36m'" | sudo tee -a ~/.bashrc >/dev/null
			echo "White=$'\e[1;37m'" | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan}Welcome to AnBox86_64!"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo ""' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan}PRoot runs within Termux and allows us to use box86/box64 & wine:"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan} * We are currently inside a PRoot (in a user account, within a Debian PRoot, within Termux, on Android)"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan} * If you exit this PRoot and go back to Termux, you can use launch_anbox86-64.sh to start this PRoot again."' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo ""' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan}Running programs:"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan} * Launch x64 programs: ${White}wine64 YourWindowsProgram.exe${Cyan} or ${White}box64 YourLinuxProgram${Cyan}."' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan} * Launch x86 programs: ${White}wine YourWindowsProgram.exe${Cyan} or ${White}box86 YourLinuxProgram${Cyan}."' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan} * Launch winetricks: ${White}BOX86_NOBANNER=1 winetricks${Cyan} or ${White}BOX64_NOBANNER=1 winetricks${Cyan}"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan}    (winetricks is currently a bit broken in AnBox86_64)"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan} * After PRoot launches a program, use the XServer XSDL Android app to view & control it."' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan}    (should launch automatically)"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo ""' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo "${Cyan}Report issues at https://github.com/lowspecman420/AnBox86"' | sudo tee -a ~/.bashrc >/dev/null
			echo 'echo ""' | sudo tee -a ~/.bashrc >/dev/null
			
			Green=$'\e[1;32m'
			echo -e "$Green\nAnBox86_64 installation complete.\n"
			
		EOT
		# The above commands were pushed into the 'user' account while we were in 'root'. So now that these commands are done, we will still be in 'root'.
		# Let's tell bash to log into the 'user' account as our final action.
		sudo su - user
	EOM
	# The above commands will be run in the future upon login to Debian PRoot as 'root' ('user' doesn't exist yet).
}

run_Main
