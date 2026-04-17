#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Compares the difference of two snapshots of the same dataset."
    echo "If a file was modified, but has the same content, it will be skipped."
    echo "Remaining files can be analysed more deeply using --singlefile mode."
    echo
    echo "Usage:"
    echo "  - $0 <dataset>@<snap1> <dataset>@<snap2> [M+-]                  # scans files, default is modified only [M]"
    echo "  - $0 <dataset>@<snap1> <dataset>@<snap2> --singlefile [path]    # deeper look at one file's differences"
    exit 1
fi

SNAP1_FULL=$1
SNAP2_FULL=$2
TYPES_FILTER=${3:-M}
TARGET_PATH=$4

DATASET=${SNAP1_FULL%@*}
SNAP1_NAME=${SNAP1_FULL#*@}
SNAP2_NAME=${SNAP2_FULL#*@}

MOUNTPOINT=$(zfs get -H -o value mountpoint "$DATASET")

if [ "$MOUNTPOINT" == "none" ] || [ ! -d "$MOUNTPOINT" ]; then
    echo "Failure: dataset is not accessable via its mountpoint."
    exit 1
fi

[ "${#TYPES_FILTER}" -gt 3 ] && [ "$TYPES_FILTER" != "--singlefile" ] \
    && [ -n "$TARGET_PATH"] \
    && echo "Failure: Mode ${TYPES_FILTER} unknown." \
    && exit 1

[ "$TYPES_FILTER" == "--singlefile" ] \
    && [ -z "$TARGET_PATH"] \
    && echo "Failure: Mode --singlefile requires path." \
    && exit 1



if [ "$TYPES_FILTER" == "--singlefile" ] && [ -n "$TARGET_PATH" ]; then
    rel_path=${TARGET_PATH#$MOUNTPOINT/}
    file1="$MOUNTPOINT/.zfs/snapshot/$SNAP1_NAME/$rel_path"
    file2="$MOUNTPOINT/.zfs/snapshot/$SNAP2_NAME/$rel_path"

    echo "Vergleiche: $rel_path"
    echo "Snapshot 1: $file1"
    echo "Snapshot 2: $file2"
    echo "--------------------------------------------------------"

    if [ ! -f "$file1" ] && [ ! -f "$file2" ]; then
        echo "Fehler: Datei existiert in beiden Snapshots nicht."
        exit 1
    fi

    # Standard Diff (meldet 'Binary files differ' bei Binärdateien)
    diff -u "$file1" "$file2"

    # Alternativ: vimdiff (einfach die obere Zeile auskommentieren und hier das # entfernen)
    # vimdiff "$file1" "$file2"

    exit 0
fi



echo -e "Diff(Bytes)\tPfad"
echo -e "--------------------------------------------------------"

zfs diff -H "$SNAP1_FULL" "$SNAP2_FULL" | while IFS=$'\t' read -r type path; do

    if [[ ! "$TYPES_FILTER" == *"$type"* ]]; then
        continue
    fi

    rel_path=${path#$MOUNTPOINT/}
    file1="$MOUNTPOINT/.zfs/snapshot/$SNAP1_NAME/$rel_path"
    file2="$MOUNTPOINT/.zfs/snapshot/$SNAP2_NAME/$rel_path"

    case "$type" in
        "M")
            if [ -f "$file1" ] && [ -f "$file2" ]; then
                read -r size1 mtime1 < <(stat -c "%s %Y" "$file1")
                read -r size2 mtime2 < <(stat -c "%s %Y" "$file2")
                diff_val=$((size2 - size1))

                if [ "$diff_val" -eq 0 ]; then
                    [ "$mtime1" == "$mtime2" ] && continue
                    hash_line1=$(sha1sum "$file1")
                    sha1_1=${hash_line1%% *}
                    hash_line2=$(sha1sum "$file2")
                    sha1_2=${hash_line2%% *}
                    [ "$sha1_1" == "$sha1_2" ] && continue
                    echo -e "0\t\t${path}"
                else
                    echo -e "${diff_val}\t\t${path}"
                fi
            fi
            ;;
        "+")
            if [ -f "$file2" ]; then
                size2=$(stat -c%s "$file2")
                echo -e "+${size2}\t\t${path}"
            fi
            ;;
        "-")
            if [ -f "$file1" ]; then
                size1=$(stat -c%s "$file1")
                echo -e "-${size1}\t\t${path}"
            fi
            ;;
    esac
done

echo -e "--------------------------------------------------------"
echo -e "Use the following command for a deeper look at one file:"
echo -e "$0 $1 $2 --singlefile [Pfad]"
