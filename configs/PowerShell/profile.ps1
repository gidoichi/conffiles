# key bindings
Import-Module PSReadLine
Set-PSReadlineOption -EditMode Emacs

# functions
function emacs(){
    emacs.exe --no-window-system $args
}
