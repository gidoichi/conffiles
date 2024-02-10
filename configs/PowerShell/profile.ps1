# PATH environment variable
$ENV:Path += ";$((Get-ChildItem 'C:\Program Files\Emacs\' -Depth 1 -Filter bin).FullName)"
$ENV:Path += ";$HOME\AppData\Roaming\.emacs.d\bin"
$ENV:Path += ';C:\Program Files\nodejs'

# key bindings
Import-Module PSReadLine
Set-PSReadlineOption -EditMode Emacs

# functions
function emacs(){
    emacs.exe --no-window-system $args
}
