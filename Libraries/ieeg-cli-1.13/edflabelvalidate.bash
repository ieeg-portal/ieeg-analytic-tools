#!/bin/bash 


# Will fail if any channel labels or file names contain a comma

gather()
{
for f in "$@"
do
  file=$(basename "$f")
  header_frag=$(head -c 192 "$f")
  #echo $header_frag
  header_size=${header_frag:184:8}
  header=$(head -c $header_size "$f")
  #echo "$header"
  data_record_duration_sec=${header:244:8}
  #echo "$data_record_duration_sec"
  no_signals=${header:252:4}
  #echo "$no_signals"
  #echo "$file has $no_signals channels"
  label_offset=256
  samples_per_data_rec_offset=$((256 + no_signals * (16 + 80 + 8 + 8 + 8 + 8 + 8 + 80)))
  for s in $(seq 1 $no_signals)
  do
      channel_label=${header:$label_offset:16}
      no_samples=${header:$samples_per_data_rec_offset:8}
      sample_rate_hz=$(echo "scale=2; $no_samples/$data_record_duration_sec" | bc)
      echo "$channel_label, $sample_rate_hz Hz, $file"
      ((label_offset += 16))
      ((samples_per_data_rec_offset += 8))
  done
done
}
no_files="$#"
# The way I have things awk's split parses channel_to_file[c] into the files for a channel plus and empty element, hence the 'no_files + 1' below
gather "$@" | awk -v no_files=$no_files -F',' ' \
         {channel_to_file[$1 $2]=channel_to_file[$1 $2] $3","} \
     END { \
       for (c in channel_to_file) { \
         no_files_for_channel=split(channel_to_file[c],files_for_channel,","); \
         if (no_files_for_channel == no_files + 1) { \
           print c" appears in all files" \
         } else { \
           file_list=channel_to_file[c]; \
           sub(/^[ \t]+/, "", file_list); \
           sub(/,$/, "", file_list); \
           print c" only appears in files "file_list \
         } \
       } \
     }' | sort

