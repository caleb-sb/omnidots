set -q BUN_INSTALL; or set -l BUN_INSTALL ~/.bun
if test -d $BUN_INSTALL/bin
    set -gx BUN_INSTALL $BUN_INSTALL
    fish_add_path -g $BUN_INSTALL/bin
end
