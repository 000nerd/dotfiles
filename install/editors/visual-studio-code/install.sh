#!/usr/bin/env bash
source ../../lib.sh

bot "Installing Visual Studio code extensions and config."

# Possibly use Extension packs instead of some of these extensions for more use
extensions=(
    EditorConfig.EditorConfig
    Poorchop.theme-darktooth
    christian-kohler.path-intellisense
    donjayamanne.githistory
    dustinsanders.an-old-hope-theme-vscode
    ionutvmi.spacegray-vscode
    jdinhlife.theme-gruvbox-dark-medium
    ms-python.python
    ms-vscode.cpptools
    msjsdiag.debugger-for-chrome
    oderwat.indent-rainbow
    redhat.java
    tomphilbin.gruvbox-themes
    vscodevim.vim
)

code -v > /dev/null
if [[ $? -eq 0 ]];then
    read -r -p "Do you want to install VSC extensions? [y|N] " configresponse
    if [[ $configresponse =~ ^(y|yes|Y) ]];then
        ok "Installing extensions please wait..."
        code --install-extension TwentyChung.jsx
        for extension in "${extensions[@]}"; do
            if code list "$extension" > /dev/null 2>&1; then
                echo "$extension already installed... skipping."
            else
                code --install-extension $extension
            fi
        done
        ok "Extensions for VSC have been installed. Please restart your VSC."
    else
        ok "Skipping extension install.";
    fi

    read -r -p "Do you want to overwrite user config? [y|N] " configresponse
    if [[ $configresponse =~ ^(y|yes|Y) ]];then
        read -r -p "Do you want to back up your current user config? [Y|n] " backupresponse
        if [[ $backupresponse =~ ^(n|no|N) ]];then
            ok "Skipping user config save."
        else
            cp $HOME/Library/Application\ Support/Code/User/settings.json $HOME/Library/Application\ Support/Code/User/settings.backup.json
            ok "Your previous config has been saved to: $HOME/Library/Application Support/Code/User/settings.backup.json"
        fi
        cp ./settings.json $HOME/Library/Application\ Support/Code/User/settings.json

        ok "New user config has been written. Please restart your VSC."
    else
        ok "Skipping user config overwriting.";
    fi
else
    error "It looks like the command 'code' isn't accessible."
    error "Please make sure you have Visual Studio Code installed"
    error "And that you executed this procedure: https://code.visualstudio.com/docs/setup/mac"
fi
