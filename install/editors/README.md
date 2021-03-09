# Folder for Editors/IDES
This folder will store my configs for my Editors and IDES.
Currently using:
* Intellij
* PyCharm
* Xcode
* Vistual Studio Code

Potential locations for research:
intellij Family:
* https://github.com/Valloric/dotfiles/tree/master/intellij

vscode:
 Use Settings Sync and maybe github as a backup if that is possible

Intellij/PyCharm:
 Use the Jetbrains Settings Sync and setup your github as a backup if possible.

 Xcode: 
  Figure out how to sync Theme. Potential themes from here:
    https://github.com/hdoria/xcode-themes

    Instructions for xcode themes
    Create and open folder ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
    Copy and paste the Gruvbox\ Material.xccolortheme file into the folder

    ```Bash
    #!/usr/bin/env bash
    mkdir -p ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
    cp *.dvtcolortheme ~/Library/Developer/Xcode/UserData/FontAndColorThemes/
    # Should be XCColorTheme not DVTColorTheme
    ```
