#!/bin/bash

LOGDIR=/srv/localhost/www/server/xml/logs
DO_DELETE=$1
if test -z "$DO_DELETE" -o -n "$2"; then
    VERBOSE=-v
fi

# Iterate over all machines
for i in "$LOGDIR"/*; do
    # Iterate over all uncompressed log files, assume that 304 logs never exceeds 16384 bytes.
    for j in `find "$i" -size -16384 -type f -name '*.log'`; do
        if fgrep -q "Skipping build because no changes were made" "$j" > /dev/null 2>&1; then
            if test -n "$DO_DELETE"; then
                rm $VERBOSE "$j"
            else
                echo "$j"
            fi
        fi
    done

    # Iterate over all compressed log files, assume that 304 logs never exceeds 10240 bytes.
    for j in `find "$i" -size -10240 -type f -name '*.log.gz'`; do
        if zcat "$j" | fgrep -q "Skipping build because no changes were made" > /dev/null 2>&1; then
            if test -n "$DO_DELETE"; then
                rm $VERBOSE "$j"
            else
                echo "$j"
            fi
        fi
    done
done
