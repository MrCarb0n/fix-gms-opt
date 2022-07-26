# ╭─────────────────────────────────────────────╮
# │      Fix GMS Optimization. | @MrCarb0n      │
# ├─────────────────────────────────────────────┤
# │     Give proper credit before doing any     │
# │        distribution or modification.        │
# │                                             │
# │     All files and codes licensed under      │
# │       GNU General Public License v3.0       │
# ├─────────────────────────────────────────────┤
# │   https://github.com/MrCarb0n/fix-gms-opt   │
# ╰─────────────────────────────────────────────╯

MODDIR=${0%/*}; . /data/adb/magisk/util_functions.sh

# banner
BANNER()
{
    ui_print "$C$(
        cat << EOF
 ___ _     _____ _____ _____         _   
|  _|_|_ _|   __|     |   __|___ ___| |_ 
|  _| |_'_|  |  | | | |__   | . | . |  _|
|_| |_|_,_|_____|_|_|_|_____|___|  _|_|  
                                |_|      
EOF
    )$N"
}

# variables
{
    # environment
    DBUG="set -x"
    IDNO="$(id -u)"
    NULL="/dev/null"
    OGDR="$(magisk --path)/.magisk/mirror"

    # script aliases
    FILE="$(basename $0)"
    BASE="fix-gms-opt.sh"
    FGOB="gmsopt"
    SRVC="service.sh"
    PFSD="post-fs-data.sh"
    UNIN="uninstall.sh"
    INST="update-binary"

    GMSX()
    {
        # gms xml components
        GMSX="\"com.google.android.gms"\"
        STR1="allow-unthrottled-location package=$GMSX"
        STR2="allow-ignore-location-settings package=$GMSX"
        STR3="allow-in-power-save package=$GMSX"
        STR4="allow-in-data-usage-save package=$GMSX"
    }

    GMSC()
    {
        # gms app components
        GMSC="com.google.android.gms"
        GAC1="auth.managed.admin.DeviceAdminReceiver"
        GAC2="mdm.receivers.MdmDeviceAdminReceiver"
        GAC3="chimera.GmsIntentOperationService"
    }
}

# output colors
PALETTE()
{
    R="\e[1;31m" G="\e[1;32m" Y="\e[1;33m" C="\e[1;36m"
    N="\e[0m"
} 2> $NULL

# magisk installation only
O_BOOTMODE()
{ [ ! -z $BOOTMODE ] || abort " ! recovery installation not supported."; }

# check android api
C_API()
{ [ $API -ge 23 ] || abort " ! Unsupported API: $API"; }

SYS_XML()
{
    GMSX
    find -L $OGDR/system -type f -iname '*.xml' -print |
        while IFS= read -r XML; do
            for X in $XML; do
                if grep -qE "$STR1|$STR2|$STR3|$STR4" $X; then
                    MISC()
                    {
                        echo "$X" |
                            awk -v ogdr="$OGDR/" \
                                '{gsub(ogdr,"");print}'
                    }
                    mkdir -p "$MODPATH/$(dirname $(MISC))"
                    cp -af "$X" "$MODPATH/$(dirname $(MISC))"
                fi
            done
        done
}

MOD_XML()
{
    GMSX
    find -L /data/adb -type f -iname "*.xml" -print |
        while IFS= read -r XML; do
            for X in $XML; do
                if grep -qE "$STR1|$STR2|$STR3|$STR4" $X; then
                    sed -i "/$STR1/d;/$STR2/d;/$STR3/d;/$STR4/d" $X
                fi
            done
        done
}

GMS_C()
{
    until [ -d /sdcard ]; do
        sleep 30
    done

    GMSC
    for U in $(ls /data/user); do
        for C in $GAC1 $GAC2 $GAC3; do
            pm $1 --user $U "$GMSC/$GMSC.$C" &> $NULL
        done
    done

    dumpsys deviceidle whitelist "$2$GMSC" &> $NULL

    exit 0
}

FGO_B()
{
    GMSC
    CHK_OPT()
    {
        [ -z "$(dumpsys deviceidle whitelist |
            grep -o $GMSC)" ] &&
            echo -e "$G $1 Optimized. $N" ||
            echo -e "$R $1 Not Optimized. $N"
    }

    case $IDNO in
        0)
            CHK_OPT "Google Play services is"
            ;;
        *)
            echo -e "$Y Superuser (su) rights is needed! $N"
            exit 1
            ;;
    esac
}

FINALIZE()
{
    ui_print "- Finalizing installation"
    mv $MODPATH/customize.sh $MODPATH/$BASE

    for S in $SRVC $PFSD $UNIN; do
        ln -sf $NVBASE/modules/$MODID/$BASE $MODPATH/$S
    done

    mkdir -p $MODPATH/system/bin
    ln -sf $NVBASE/modules/$MODID/$BASE $MODPATH/system/bin/$FGOB

    # clean up
    ui_print "  Cleaning obsolete files"
    find -L $MODPATH/* -maxdepth 0 \
                     ! -name "$BASE" \
                     ! -name "$PFSD" \
                     ! -name "$SRVC" \
                     ! -name "$UNIN" \
                     ! -name "module.prop" \
                     ! -name "system" \
                       -exec rm -rf {} \;

    # settings dir and file permission
    ui_print "  Settings permissions"
    set_perm_recursive $MODPATH 0 0 0755 0644
    chown -h 0:2000 $MODPATH/system/bin/$FGOB
}

case $FILE in
    $INST)
        $DBUG
        BANNER
        O_BOOTMODE
        C_API
        SYS_XML
        MOD_XML
        FINALIZE
        ;;
    $PFSD)
        MOD_XML
        ;;
    $SRVC)
        GMS_C disable -
        ;;
    $FGOB)
        PALETTE
        BANNER
        FGO_B
        ;;
    $UNIN)
        GMS_C enable +
        ;;
esac
