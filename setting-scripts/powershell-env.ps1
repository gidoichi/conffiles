# winget
winget install Git --source winget
winget install 'GNU Emacs'
winget install 'Google Chrome'
winget install KeePassXC --source winget
winget install 'Node.js LTS'
winget install Ubuntu
winget install Yandex.Disk

# scoop
if ( -not ( Get-Command scoop ) )
{
    Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
}
scoop install ghq

# ghq
ghq get https://github.com/doomemacs/doomemacs.git
New-Item -Value "$(ghq root)/github.com/doomemacs/doomemacs" -Path "$HOME/AppData/Roaming/.emacs.d" -ItemType Junction
