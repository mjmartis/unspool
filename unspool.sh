#/bin/sh
readonly SEG_LENGTH_MIN=10
readonly SEG_LENGTH_SEC=$((SEG_LENGTH_MIN * 60))

if [[ $# != 3 ]]; then
  echo "Usage: $0 infile title outprefix"
  exit 1
fi

readonly in_fn="$1"
readonly in_dir=$(dirname "$1")
readonly title="$2"
readonly out_prefix="$3"
readonly ext="${in_fn#*.}"

# First, split audio into chunks and save the number of
# chunks extracted.
echo "Splitting original audio into segments."
readonly seg_count=$(
  ffmpeg -i "${in_fn}" \
         -f segment -segment_time ${SEG_LENGTH_SEC} \
         -c copy \
         "${in_dir}/${out_prefix}_%03d.${ext}" \
         2>&1 | \
  grep "Opening .* for writing" -c -
)

# File to output to, since we can't read and write to
# the same file.
readonly tmp_fn="$(mktemp --suffix ".${ext}")"

# Second, prepend chunk description audio to each file.
for (( i=0; i<${seg_count}; ++i )); do
  echo "Prepending description to segment $((i+1)) of ${seg_count}."

  # The current chunk to read from / write to.
  cur_fn="$(printf "${in_dir}/${out_prefix}_%03d.${ext}" $i)"

  # Generate description then concatenate it to chunk. Writes
  # to our temporary file.
  gtts-cli "${title}. part $((i+1)) of ${seg_count}." | \
  ffmpeg -y -i - -i "${cur_fn}" \
         -filter_complex "[0:a][1:a]concat=n=2:v=0:a=1[a]" \
         -map "[a]" "${tmp_fn}" \
         2>/dev/null

  # Overwrite chunk file with the copy that has a description.
  cp -f "${tmp_fn}" "${cur_fn}"
done
