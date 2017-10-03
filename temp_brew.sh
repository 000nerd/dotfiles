table File  179 lines (152 sloc)  5.05 KB
#!/usr/bin/env bash

# Install command-line tools using Homebrew.

# Ask for the administrator password upfront.
sudo -v

# Keep-alive: update existing `sudo` time stamp until the script has finished.
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Check for Homebrew,
# Install if we don't have it
if test ! $(which brew); then
  echo "Installing homebrew..."
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade --all

# Install GNU core utilities (those that come with OS X are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
sudo ln -s /usr/local/bin/gsha256sum /usr/local/bin/sha256sum

# Install some other useful utilities like `sponge`.
brew install moreutils
# Install GNU `find`, `locate`, `updatedb`, and `xargs`, `g`-prefixed.
brew install findutils
# Install GNU `sed`, overwriting the built-in `sed`.
brew install gnu-sed --with-default-names
# Install Bash 4.
brew install bash-completion2

# Install `wget` with IRI support.
brew install wget --with-iri

# Install some CTF tools; see https://github.com/ctfs/write-ups.
brew install aircrack-ng
brew install bfg
brew install binutils
brew install binwalk
brew install cifer
brew install dex2jar
brew install dns2tcp
brew install fcrackzip
brew install foremost
brew install hashpump
brew install hydra
brew install john
brew install knock
brew install netpbm
brew install nmap
brew install pngcheck
brew install socat
brew install sqlmap
brew install tcpflow
brew install tcpreplay
brew install tcptrace
brew install ucspi-tcp # `tcpserver` etc.
brew install homebrew/x11/xpdf
brew install xz

# Install other useful binaries.
brew install dark-mode
#brew install exiv2
brew install git
brew install git-lfs
brew install git-flow
brew install git-extras
brew install hub
brew install imagemagick --with-webp
brew install lynx
brew install p7zip
brew install pigz
brew install pv
brew install rename
brew install rhino
brew install ssh-copy-id
brew install webkit2png
brew install zopfli
brew install pkg-config libffi
brew install pandoc
brew install z
brew install zsh

# Install other useful binaries.
brew install testssl
brew install openssh
brew install rsync
brew install gcc --enable-all-languages
brew install nmap
brew install gzip

# Install GNU core utilities (those that come with OS X are outdated).
# Don’t forget to add `$(brew --prefix coreutils)/libexec/gnubin` to `$PATH`.
brew install coreutils
sudo ln -s /usr/local/bin/gsha256sum /usr/local/bin/sha256sum

# Install some other useful utilities like `sponge`.
brew install moreutils

# Install GNU `find`, `locate`, `updatedb`, and `xargs`.
brew install findutils --with-default-names

# Install other GNU utilities, overwriting the built-ins.
brew install gnu-sed --with-default-names
brew install gnu-tar --with-default-names
brew install gnu-which --with-default-names
brew install gnu-indent --with-default-names
brew install gnutls --with-default-names
brew install grep --with-default-names
brew install binutils
brew install diffutils
brew install gawk
brew install gzip
brew install screen
brew install watch
brew install wdiff --with-gettext

# Lxml and Libxslt
brew install libxml2
brew install libxslt
brew link libxml2 --force
brew link libxslt --force

# Install more recent versions of some OS X tools.
brew install vim --override-system-vi
brew install homebrew/dupes/grep
brew install homebrew/dupes/openssh
brew install homebrew/dupes/screen
brew install homebrew/dupes/lsof

#!/bin/bash

# Install homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Taps
brew tap neovim/neovim
brew tap thoughtbot/formulae
brew tap caskroom/cask

# Installs
brew install 'ack'
brew install 'automake'
brew install 'calc'
brew install 'cmake'
brew install 'coreutils'
brew install 'cowsay'
brew install 'ctags'
brew install 'doxygen'
brew install 'editorconfig'
brew install 'fortune'
brew install 'git'
brew install 'git-flow'
brew install 'grip'
brew install 'iandrewt/tap/gpmdp-remote'
brew install 'ical-buddy'
brew install 'koekeishiya/formulae/kwm'
brew install 'libksba'
brew install 'lua'
brew install 'mas'
brew install 'mongodb'
brew install 'mysql'
brew install 'neofetch'
brew install 'neovim/neovim/neovim'
brew install 'perl'
brew install 'python'
brew install 'python3'
brew install 'reattach-to-user-namespace'
brew install 'rcm'
brew install 'ruby'
brew install 'source-highlight'
brew install 'the_silver_searcher'
brew install 'thoughtbot/formulae/rcm'
brew install 'tmux'
brew install 'tomanthony/brews/itermocil'
brew install 'trash'
brew install 'tree'
brew install 'utf8proc'
brew install 'watchman'
brew install 'youtube-dl'

# Casks
brew cask install 'android-studio'
brew cask install 'dropbox'
brew cask install 'firefox'
brew cask install 'flux'
brew cask install 'franz'
brew cask install 'google-chrome'
brew cask install 'google-play-music-desktop-player'
brew cask install 'iterm2'
brew cask install 'ubersicht'
brew cask install 'rightfont'
brew cask install 'sketch'
brew cask install 'subtitles'

# Mas Will install my apps from the App Store for me
mas install 497799835         # Xcode (8.2.1)
mas install 409183694         # Keynote (7.0.5)
mas install 409201541         # Pages (6.0.5)
mas install 409203825         # Numbers (4.0.5)
mas install 425424353         # The Unarchiver (3.11.1)
mas install 417602904         # CloudApp (4.1.1)
mas install 443987910         # 1Password (6.5.3)
mas install 775737590         # iA Writer (4.0.2)
mas install 1062679359        # typeface (1.5.2)
mas install 557168941         # Tweetbot (2.4.6)
mas install 969418666         # ColorSnapper2 (1.3.1)
mas install 937984704         # Amphetamine (3.0.2)
mas install 992076693         # MindNode (2.4.6)
mas install 1081413713        # GIF Brewery 3 (3.4.1)
mas install 1031163338        # GIFHunter (1.0.12)
mas install 638332853         # Logitech Camera Settings (3.31.623)
mas install 948176063         # Boom 2 (1.6)
mas install 1035350363        # Teeny Tokyo (1.2)
mas install 872515009         # Pomodoro Timer (1.5)
mas install 969418666         # ColorSnapper2 (1.3.1)
