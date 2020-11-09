@ECHO OFF
COLOR 1F
SET GITORG=vickunwu
SET GITPRJ=xWSL
SET BRANCH=master
SET DOWNLOADAREA=C:\WSL\downloads
SET BASE=https://github.com/%GITORG%/%GITPRJ%/raw/%BRANCH%

REM ## UAC Check 
NET SESSION >NUL 2>&1
 if %errorLevel% == 0 (
      echo Administrative permissions confirmed...
  ) else (
      echo You need to run this command with administrative rights.  User Account Control enabled?
      pause
      goto ENDSCRIPT
  )

REM ## Enable WSL
POWERSHELL.EXE -command "dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart"
POWERSHELL.EXE -command "dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart"

REM ## Get installation parameters
:DI
CLS && SET RUNSTART=%date% @ %time%
IF EXIST .\CMD.EXE CD ..\..
ECHO [xWSL Installer]
ECHO:
ECHO Enter a unique name for the distro or hit Enter to use default 
SET DISTRO=xWSL& SET /p DISTRO=Keep the name simple, no space or underscore characters [xWSL]: 
IF EXIST %DISTRO%\*.VHDX GOTO DI
IF EXIST %DISTRO%\rootfs GOTO DI
REM ## Determine ideal DPI
IF NOT EXIST "%DOWNLOADAREA%\dpi.ps1" POWERSHELL.EXE -ExecutionPolicy Bypass -Command "wget '%BASE%/dpi.ps1' -UseBasicParsing -OutFile '%DOWNLOADAREA%\dpi.ps1'"
FOR /f "delims=" %%a in ('powershell -ExecutionPolicy bypass -command "%DOWNLOADAREA%\dpi.ps1" ') do set "LINDPI=%%a"
ECHO:
                 SET /p LINDPI=Set custom DPI scale or hit Enter to use Windows value [%LINDPI%]: 
SET RDPPRT=3399& SET /p RDPPRT=Port number for xRDP traffic or hit Enter to use default [3399]: 
SET SSHPRT=3322& SET /p SSHPRT=Port number for SSHd traffic or hit Enter to use default [3322]: 
SET DEFEXL=NONO& SET /p DEFEXL=[Not recommended!] Type X to eXclude %DISTRO% from Windows Defender: 

SET DISTROFULL=%CD%\%DISTRO%
SET _rlt=%DISTROFULL:~2,2%
IF "%_rlt%"=="\\" SET DISTROFULL=%CD%%DISTRO%
SET GO="%DISTROFULL%\LxRunOffline.exe" r -n "%DISTRO%" -c
ECHO:
ECHO Download and install "%DISTRO%" to location "%DISTROFULL%" 
IF NOT EXIST "%DOWNLOADAREA%\Ubuntu2004.zip" POWERSHELL.EXE -Command "Start-BitsTransfer -source https://aka.ms/wslubuntu2004 -destination '%DOWNLOADAREA%\Ubuntu2004.zip'"
POWERSHELL.EXE -command "Expand-Archive -Path '%DOWNLOADAREA%\Ubuntu2004.zip' -DestinationPath '%DOWNLOADAREA%'" -force
%DISTROFULL:~0,1%: & MKDIR "%DISTROFULL%" & CD "%DISTROFULL%" & MKDIR logs & TakeOwn /f %DISTROFULL% /r /d y > NUL
ECHO:
ECHO Installing Ubuntu 20.04...
IF NOT EXIST "%DOWNLOADAREA%\LxRunOffline.exe" POWERSHELL.EXE -Command "wget %BASE%/LxRunOffline.exe -UseBasicParsing -OutFile '%DOWNLOADAREA%\LxRunOffline.exe'"
START /WAIT /MIN "Installing Distro Base..." "%DOWNLOADAREA%\LxRunOffline.exe" "i" "-n" "%DISTRO%" "-f" "%DOWNLOADAREA%\install.tar.gz" "-d" "%DISTROFULL%"
"%DOWNLOADAREA%\LxRunOffline.exe" sd -n "%DISTRO%"
COPY "%DOWNLOADAREA%\LxRunOffline.exe" "%DISTROFULL%" > NUL
ECHO:
ECHO Add exclusions in Windows Defender if requested...
POWERSHELL.EXE -Command "wget %BASE%/excludeWSL.ps1 -UseBasicParsing -OutFile '%DISTROFULL%\excludeWSL.ps1'"
IF %DEFEXL%==X POWERSHELL.EXE -ExecutionPolicy bypass -Command ".\excludeWSL.ps1 '%DISTROFULL%'"
DEL "%DISTROFULL%\excludeWSL.ps1"
ECHO:
ECHO Download xWSL overlay...
(ECHO [xWSL Inputs] && ECHO. && ECHO.   Distro: %DISTRO% && ECHO.     Path: %DISTROFULL% && ECHO. RDP Port: %RDPPRT% && ECHO. SSH Port: %SSHPRT%  && ECHO.DPI Scale: %LINDPI% && ECHO.) > .\logs\Step0_Inputs.log

CD "%DISTROFULL%"
ECHO Change Repo
%GO% "cp /etc/apt/sources.list /etc/apt/sources.list.bak"
%GO% "sed -i 's/http:\/\/.*.ubuntu.com/https:\/\/mirrors.ustc.edu.cn/g' /etc/apt/sources.list"
%GO% "apt-get update"

%GO% "cd /tmp ; git clone -b %BRANCH% --depth=1 https://github.com/%GITORG%/%GITPRJ%.git"
%GO% "ssh-keygen -A ; mkdir -p /root/.local/share ; apt-get update" > .\logs\Step1_Update.log
ECHO:
ECHO Install base packages, please wait...
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install /tmp/xWSL/deb/gksu_2.1.0_amd64.deb /tmp/xWSL/deb/libgksu2-0_2.1.0_amd64.deb /tmp/xWSL/deb/libgnome-keyring0_3.12.0-1+b2_amd64.deb /tmp/xWSL/deb/libgnome-keyring-common_3.12.0-1_all.deb /tmp/xWSL/deb/multiarch-support_2.27-3ubuntu1_amd64.deb /tmp/xWSL/deb/xrdp_0.9.13.1-2_amd64.deb /tmp/xWSL/deb/xorgxrdp_0.2.12-1_amd64.deb /tmp/xWSL/deb/plata-theme_0.9.8-0ubuntu1~focal1_all.deb /tmp/xWSL/deb/papirus-icon-theme_20200901-4672+pkg21~ubuntu20.04.1_all.deb /tmp/xWSL/deb/fonts-cascadia-code_2005.15-1_all.deb --no-install-recommends" > .\logs\Step2_BasePackages.log
ECHO:
ECHO Install dependencies for desktop environment...
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install x11-apps x11-session-utils x11-xserver-utils pulseaudio dialog distro-info-data lsb-release dumb-init inetutils-syslogd xdg-utils avahi-daemon libnss-mdns binutils putty synaptic pulseaudio-utils pulseaudio mesa-utils bzip2 p7zip-full unar unzip zip libatkmm-1.6-1v5 libcairomm-1.0-1v5 libcanberra-gtk3-0 libcanberra-gtk3-module libglibmm-2.4-1v5 libgtkmm-3.0-1v5 libpangomm-1.4-1v5 libsigc++-2.0-0v5 dbus-x11 libdbus-glib-1-2 libqt5core5a --no-install-recommends" > .\logs\Step5_DesktopDeps.log
ECHO:
ECHO Install XFCE4...
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install xfce4-terminal xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin pavucontrol xfwm4 xfce4-panel xfce4-session xfce4-settings thunar thunar-volman thunar-archive-plugin xfdesktop4 xfce4-screenshooter libsmbclient gigolo gvfs-fuse gvfs-backends gvfs-bin mousepad evince xarchiver lhasa lrzip lzip lzop ncompress zip unzip dmz-cursor-theme adapta-gtk-theme gconf-defaults-service xfce4-taskmanager hardinfo --no-install-recommends" > .\logs\Step6_XFCE4.log
ECHO:
ECHO Install Multimedia Components...
%GO% "DEBIAN_FRONTEND=noninteractive apt-get -y install mtpaint parole" > .\logs\Step7_Media.log
REM ## Additional items to install can go here...
REM ## %GO% "cd /tmp ; wget https://files.multimc.org/downloads/multimc_1.4-1.deb"
REM ## %GO% "apt-get -y install extremetuxracer tilix /tmp/multimc_1.4-1.deb"
REM ## Things to do: Install Firefox; Install Rime; Install Tor;
ECHO:
ECHO Cleaning up...
%GO% "rm -rf /etc/apt/apt.conf.d/20snapd.conf /etc/rc2.d/S01whoopsie /etc/init.d/console-setup.sh"
%GO% "apt-get -qq purge cryptsetup cryptsetup-bin cryptsetup-initramfs cryptsetup-run irqbalance multipath-tools apparmor snapd squashfs-tools libplymouth5 plymouth plymouth-theme-ubuntu-text open-vm-tools cloud-init isc-dhcp-* gnustep* lvm2* mdadm apport open-iscsi powermgmt-base popularity-contest fwupd libfwupd2 ; apt-get -qq autoremove ; apt-get -qq clean" > .\logs\Step8_Cleanup.log
IF %LINDPI% GEQ 288 ( %GO% "sed -i 's/HISCALE/3/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/HISCALE/2/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/Default-hdpi/Default-xhdpi/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/Segoe UI Semi-Bold 11/Segoe UI Semi-Bold 22/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )
IF %LINDPI% GEQ 192 ( %GO% "sed -i 's/QQQ/96/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% LSS 192 ( %GO% "sed -i 's/QQQ/%LINDPI%/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% LSS 192 ( %GO% "sed -i 's/HISCALE/1/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" )
IF %LINDPI% LSS 120 ( %GO% "sed -i 's/Default-hdpi/Default/g' /tmp/xWSL/dist/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" )
SET /A SESMAN = %RDPPRT% - 50
%GO% "sed -i 's/ListenPort=3350/ListenPort=%SESMAN%/g' /etc/xrdp/sesman.ini"
%GO% "sed -i 's/thinclient_drives/.xWSL/g' /etc/xrdp/sesman.ini"
%GO% "sed -i 's/port=3389/port=%RDPPRT%/g' /tmp/xWSL/dist/etc/xrdp/xrdp.ini ; cp /tmp/xWSL/dist/etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini"
%GO% "sed -i 's/#Port 22/Port %SSHPRT%/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config"
%GO% "sed -i 's/XWSLINSTANCENAME/%DISTRO%/g' /tmp/xWSL/dist/usr/local/bin/initWSL"
%GO% "sed -i 's/\\h/%DISTRO%/g' /tmp/xWSL/dist/etc/skel/.bashrc"
%GO% "sed -i 's/#enable-dbus=yes/enable-dbus=no/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/#host-name=foo/host-name=%COMPUTERNAME%-%DISTRO%/g' /etc/avahi/avahi-daemon.conf ; sed -i 's/use-ipv4=yes/use-ipv4=no/g' /etc/avahi/avahi-daemon.conf"
%GO% "cp /mnt/c/Windows/Fonts/*.ttf /usr/share/fonts/truetype ; rm -rf /etc/pam.d/systemd-user ; rm -rf /etc/systemd ; rm -rf /usr/share/icons/breeze_cursors ; rm -rf /usr/share/icons/Breeze_Snow/cursors ; ssh-keygen -A ; adduser xrdp ssl-cert"
%GO% "mv /usr/bin/pkexec /usr/bin/pkexec.orig ; echo gksudo -k -S -g \$1 > /usr/bin/pkexec ; chmod 755 /usr/bin/pkexec"
%GO% "chmod 644 /tmp/xWSL/dist/etc/wsl.conf"
%GO% "chmod 644 /tmp/xWSL/dist/var/lib/xrdp-pulseaudio-installer/*.so"
%GO% "chmod 700 /tmp/xWSL/dist/usr/local/bin/initWSL ; chmod 700 /tmp/xWSL/dist/etc/skel/.config ; chmod 700 /tmp/xWSL/dist/etc/skel/.local ; chmod 700 /tmp/xWSL/dist/etc/skel/.gconf ; chmod 700 /tmp/xWSL/dist/etc/skel/.mozilla"
%GO% "chmod 644 /tmp/xWSL/dist/etc/profile.d/WinNT.sh"
%GO% "chmod 644 /tmp/xWSL/dist/etc/xrdp/xrdp.ini"
%GO% "cp -r /tmp/xWSL/dist/* /"
%GO% "rm -rf /etc/skel/.mozilla/seamonkey"
%GO% "strip --remove-section=.note.ABI-tag /usr/lib/x86_64-linux-gnu/libQt5Core.so.5"
SET RUNEND=%date% @ %time%
CD %DISTROFULL% 
ECHO:
ECHO:
SET /p XU=Enter name of %DISTRO% user: 
POWERSHELL -Command $prd = read-host "Enter password for %XU%" -AsSecureString ; $BSTR=[System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($prd) ; [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) > .tmp & set /p PWO=<.tmp
BASH -c "useradd -m -p nulltemp -s /bin/bash %XU%"
BASH -c "echo %XU%:%PWO% | chpasswd"
%GO% "sed -i 's/PLACEHOLDER/%XU%/g' /tmp/xWSL/xWSL.rdp"
%GO% "sed -i 's/COMPY/%COMPUTERNAME%-%DISTRO%\.local/g' /tmp/xWSL/xWSL.rdp"
%GO% "sed -i 's/RDPPRT/%RDPPRT%/g' /tmp/xWSL/xWSL.rdp"
%GO% "cp /tmp/xWSL/xWSL.rdp ./xWSL._"
ECHO $prd = Get-Content .tmp > .tmp.ps1
ECHO ($prd ^| ConvertTo-SecureString -AsPlainText -Force) ^| ConvertFrom-SecureString ^| Out-File .tmp  >> .tmp.ps1
POWERSHELL -ExecutionPolicy Bypass -Command ./.tmp.ps1
TYPE .tmp>.tmpsec.txt
COPY /y /b xWSL._+.tmpsec.txt "%DISTROFULL%\%DISTRO%.rdp" > NUL
DEL /Q  xWSL._ .tmp*.* > NUL
BASH -c "echo '%XU% ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers"
ECHO:
ECHO Open Windows Firewall Ports for xRDP, SSH, mDNS...
NETSH AdvFirewall Firewall add rule name="%DISTRO% xRDP" dir=in action=allow protocol=TCP localport=%RDPPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Secure Shell" dir=in action=allow protocol=TCP localport=%SSHPRT% > NUL
NETSH AdvFirewall Firewall add rule name="%DISTRO% Avahi Multicast DNS" dir=in action=allow program="%DISTROFULL%\rootfs\usr\sbin\avahi-daemon" enable=yes > NUL
ECHO Building RDP Connection file, Console link, Init system...
ECHO @WSLCONFIG /t %DISTRO% >  "%DISTROFULL%\Init.cmd"
ECHO @WSL ~ -u root -d %DISTRO% -e initWSL 2 >> "%DISTROFULL%\Init.cmd"
ECHO @WSL ~ -u %XU% -d %DISTRO% > "%DISTROFULL%\Console.cmd"
POWERSHELL -Command "Copy-Item '%DISTROFULL%\Console.cmd' ([Environment]::GetFolderPath('Desktop'))"
POWERSHELL -Command "Copy-Item '%DISTROFULL%\%DISTRO%.rdp' ([Environment]::GetFolderPath('Desktop'))"
ECHO Building Uninstaller... [%DISTROFULL%\%DISTRO%_Uninstall.cmd]
ECHO @COLOR 1F                                                                                                   >  "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @ECHO Uninstall %DISTRO%?                                                                                   >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @PAUSE                                                                                                      >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @COPY /Y "%DISTROFULL%\LxRunOffline.exe" "%DOWNLOADAREA%"                                                           >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @POWERSHELL -Command "Remove-Item ([Environment]::GetFolderPath('Desktop')+'\Console.cmd')" >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @POWERSHELL -Command "Remove-Item ([Environment]::GetFolderPath('Desktop')+'\%DISTRO%.rdp')" >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @SCHTASKS /Delete /TN:%DISTRO% /F                                                                           >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @CLS                                                                                                        >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @CD ..                                                                                                      >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @ECHO Uninstalling %DISTRO%, please wait...                                                                 >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @WSLCONFIG /T %DISTRO%                                                                                      >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @"%DOWNLOADAREA%\LxRunOffline.exe" ur -n %DISTRO%                                                                   >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO @RD /S /Q "%DISTROFULL%"                                                                                    >> "%DISTROFULL%\Uninstall %DISTRO%.cmd"
ECHO Building Scheduled Task...
POWERSHELL -C "$WAI = (whoami) ; (Get-Content .\rootfs\tmp\xWSL\xWSL.xml).replace('AAAA', $WAI) | Set-Content .\rootfs\tmp\xWSL\xWSL.xml"
POWERSHELL -C "$WAC = (pwd)    ; (Get-Content .\rootfs\tmp\xWSL\xWSL.xml).replace('QQQQ', $WAC) | Set-Content .\rootfs\tmp\xWSL\xWSL.xml"
SCHTASKS /Create /TN:%DISTRO% /XML .\rootfs\tmp\xWSL\xWSL.xml /F
SET USER=wsl -u %XU% -d %DISTRO%
%USER% "sudo apt-get -y install firefox-esr"
%USER% "sudo apt-get -y install tor"
%USER% "echo 'ExcludeNodes cn,hk,mo,kp,ir,sy,pk,cu,vn' | sudo tee -a /etc/tor/torrc"
%USER% "echo 'strictnodes 1' | sudo tee -a /etc/tor/torrc"
%USER% "sudo apt-get -y install ibus-rime ; ibus restart ; ibus engine rime"
%USER% "cp -r /tmp/xWSL/dist/clover-pinyin/* /home/$(ls /home)/.config/ibus/rime ; touch /home/$(ls /home)/.config/ibus/rime/ ; ibus restart"
%USER% "rm -rf /tmp/xWSL/dist/clover-pinyin"
REM ## Convert to WSL2
wsl --set-version %DISTRO% 2
START /MIN "%DISTRO% Init" WSL ~ -u root -d %DISTRO% -e initWSL 2
ECHO:
ECHO:      Start: %RUNSTART%
ECHO:        End: %RUNEND%
%GO%  "echo -ne '   Packages:'\   ; dpkg-query -l | grep "^ii" | wc -l "
ECHO: 
ECHO:  - xRDP Server listening on port %RDPPRT% and SSHd on port %SSHPRT%.
ECHO: 
ECHO:  - Links for GUI and Console sessions have been placed on your desktop.
ECHO: 
ECHO:  - (Re)launch init from the Task Scheduler or by running the following command: 
ECHO:    schtasks /run /tn %DISTRO%
ECHO: 
ECHO: %DISTRO% Installation Complete!  GUI will start in a few seconds...  
PING -n 6 LOCALHOST > NUL
START "Remote Desktop Connection" "MSTSC.EXE" "/V" "%DISTROFULL%\%DISTRO%.rdp"
CD ..
ECHO: 
:ENDSCRIPT