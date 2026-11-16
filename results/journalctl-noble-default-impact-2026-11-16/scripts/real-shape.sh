#!/bin/bash
# Counts and sizes only: the shape of the laptop's journal directory (read only, nothing printed but numbers).
dir=$(ls -d /var/log/journal/*/ | head -1)
total=$(ls "$dir" | grep -c '[.]journal')
user=$(ls "$dir" | grep -c '^user-.*[.]journal')
sys=$(ls "$dir" | grep -c '^system.*[.]journal')
bytes=$(du -sb "$dir" | cut -f1)
echo "files $total system $sys user $user bytes $bytes"
