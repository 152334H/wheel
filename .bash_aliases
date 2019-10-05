alias dd='dd bs=512K conv=noerror,sync status=progress'
alias fdl='sudo fdisk -l'
alias git-clone='git clone --depth=1'
alias ind='expr index'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias mnt='sudo mount'
alias mv='mv -i'
alias newline-rm="sed '/^$/d'"
alias shrm='shred -n1 --remove=wipe'
alias umnt='sudo umount'
alias vi='vim -p'
## notes:
#generally one-liners lack description, while screen-long functions have built-in descriptions.
#subshells are to be avoided unless necessary
#non-subshell variables should always be declared with a `local`.
#64 is the return code for help messages (EX_USAGE), 1 is the return code for a lack of options/general failure.
#
#[ ] is preferred to [[ ]] or (( )).
#cat<<EOF...EOF, [ COND ]&&CMD, [ ! COND ]||CMD, etc. are permissible to shorten code.
#if/while/for/case statements should follow like this:
#ACT [ COND ]
#START  CMD
#       CMD
#END
argc(){ echo $#; }
c(){ cd "$1"; l; }
errpt(){        #local function, to print bold red errors
        echo -en '\033[1;31m'
        echo -n "$1"
        echo -e '\033[0;0m'
        return 1        #general error return code
}
ffmpa(){        #extract audio from video file
        if [ $# -eq 2 ]
        then    echo 'ffmpeg -i "$1" -acodedc copy -vn "$2"'
                ffmpeg -i "$1" -c:a copy -vn "$2"
        else    cat<<EOF
ffmpa:  extract audio from a video
        ffmpa INPUT OUTPUT
EOF
                return 64
        fi
}
find-v(){       #!todo: add capability for multiple globs
        if [ $# -gt 0 ]
        then    local DIR=".";local GLOB=""
                if [ -d "$1" ]
                then    DIR="$1";GLOB="$2"
                else    [ -d "$2" ]&&DIR="$2"
                        GLOB="$1"
                fi                                                      #e.g. find . -type f ! -name "*.tes" ! -name "*.ting"
                find "$DIR" '!' -name "$GLOB"
        else    cat<<EOF
find-v: functional alias for inverse find
        find-v [DIRECTORY] GLOB
e.g.    find-v /tmp/ '*.txt'
        find-v '*.mkv'          #defaults to searching in ./
EOF
                return 64
        fi
}
grep-o(){       #grep -o, implemented with awk owing to speed issues with grep
        if [ $# -gt 1 -a -e "$2" ]
        then    local file="$2"
                local pat="$1"
                local bef="${3:-100}"   #if bef=="" then bef=100
                local aft=$(( ${4:-100} + $bef )) #if aft=="" then aft=200
                awk "/${pat}/ { match(\$0, /${pat}/); print substr(\$0, RSTART - ${bef}, RLENGTH + ${aft}); }" "$file"
        else    cat<<EOF
grep-o - grep PATTERN in FILE and print characters BEFORE and AFTER match
         grep PATTERN FILE [BEFORE] [AFTER]
EOF
                return 64
        fi
}
lbl(){ #to label devices without needing to manually find FS type
        local DEV=""    #full pathname of device
        local LBL=""    #desired label
        case $# in      #boilerplate argument parsing
                0) [ -b "/dev/sdb1" ]&&DEV="/dev/sdb1";;
                1)      if [ -b "$1" ]
                        then    DEV="$1"
                        else    LBL="$1"
                                [ -b "/dev/sdb1" ]&&DEV="/dev/sdb1"
                        fi;;
                2)      if [ -b "$2" ]
                        then    DEV="$2";LBL="$1"
                        elif [ -b "$1" ]
                        then    DEV="$1";LBL="$2"
                        else    errpt "err: device not found"
                        fi;;
        esac
        if [ -z "$DEV" ]||[[ ! "${DEV: -1}" =~ [0-9] ]]         #if DEV unknown/invalid
        then    cat<<EOF
        lbl [LABEL|DEVICE], argc <= 2
e.g.    lbl t /dev/sdb2 - labels /dev/sdb2 as "t"
        lbl DEVICE LABEL- labels DEVICE as LABEL
        lbl DEVICE      - labels DEVICE as its fs type
        lbl             - labels /dev/sdb1 automatically as its fs type by default
        lbl LABEL       - labels /dev/sdb1 automatically as LABEL
Labels cannot be of any onboard /dev/sd* variety (i.e. trying to label /dev/sdb1 as '/dev/sdb1' will return an error).
To create a blank label, name the label as '/'.
EOF
                return 64
        fi
        local FS=`lsblk -f "$DEV"|egrep "^${DEV:5} [[:alnum:]]*" -o|sed "s/${DEV:5} //"`        #get FS type
        : ${LBL:="$FS"}                                                                 #use FS type as label, if no given label
        [[ "$LBL" =~ "/" ]]&&LBL=`echo "$LBL"|tr -d '/'`                                #remove '/' from label; illegal in all FS
        LBL="${LBL::255}"                                                               #(silently) ignore excessively long labels
        if [ "$FS" == "vfat" ]  #fat* filesystems in general have strict naming conventions
        then    echo "checking vfat label for safety..."
                [[ "${LBL::1}" =~ [a-z] ]]&&LBL=`echo "$LBL"|sed -e 's/\(.\)/\u\1/'`    #set first letter uppercase
                LBL=`echo "$LBL"|tr -d '\\\     []*?.,;:|+=<>'`                         #remove (other) illegal characters
                LBL="${LBL::11}"                                                        #trunc label to 11 characters
        fi
        echo "labelling $DEV of $FS filesystem as $LBL" #notify user
        case "$FS" in   #!ntfs remains unimplemented
                "vfat") sudo fatlabel "$DEV" "$LBL";;
                "ext2") sudo e2label "$DEV" "$LBL";;
                *) errpt "cannot stat filesystem type, aborting";return 1
        esac
}
pdfencrypt(){ [ -z "$1" -o -z "$3" -o ! -f "$2" ]&&echo pdfencrypt PASS FILE OUTPUT - encrypt a pdf FILE with password PASS||qpdf --encrypt "$1" "$1" 256 -- "$2" "$3";}
shrm-r(){
        if [ $# -eq 0 ]
        then    cat<<EOF
shrm-r - shred a directory recursively
 usage: shrm-r DIR
This command is highly unsafe. Use at your own peril.
EOF
                return 64
        fi
        if echo "$@"|grep -q -e '/sys' -e ' / ' -e '/dev' -e '^/ ' -e ' /$' -e '^/$'
        then    errpt "Please do not attempt to destroy the system."
                return 1
        fi
        while [ $# -ne 0 ]
        do      if [ -d "$1" ]
                then    for f in `find "$1"`    #highly unsafe
                        do      [ -s "$f" ]&&shrm "$f" #note that symlinks and etc still remain
                        done
                        rm -r "$1"
                elif [ -f "$1" ]
                then    shrm "$1"
                else errpt 'err: '"'$1'"' is not a shredable thing'
                fi
                shift
        done
}
