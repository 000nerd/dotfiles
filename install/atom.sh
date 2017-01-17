#!/usr/bin/env bash

##############################################################################
#                                  Atom                                      #
############################################################################## 
if test ! $(which brew); then
    echo "Installing homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

echo -e "\n\nInstalling atom"
echo "=============================="

brew cask install atom

atom_packages=(
	atom-beautify
	autocomplete-paths
	autocomplete-python
	autocomplete-java
	color-picker
	docblockr
	file-icons
	linter
	linter-flake8
	minimap
	python-tools
	tag
	trailing-spaces
	gruvbox-plus-syntax
	language-swift
	swift-debugger
	native-ui
	editorconfig
	merge-conflicts
	vim-surround
	vim-mode
	pigments
)

for package in "${atom_packages[@]}"; do
   apm install "$package"
done

# Remove outdated versions from the cellar.
brew cleanup
