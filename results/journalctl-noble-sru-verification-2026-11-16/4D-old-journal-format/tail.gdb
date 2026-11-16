set debuginfod enabled off
set debug-file-directory /work/pkgx/p820dbg/usr/lib/debug
set breakpoint pending on
set confirm off
break journal_file_read_tail_timestamp
commands
silent
printf "hs=%lu has_tail_entry_offset=%d\n", f->header->header_size, f->header->header_size >= 272
continue
end
run
quit
