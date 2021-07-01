#!/bin/sh

set -e
#set -x

for arg; do
  shift
  case "$arg" in
    --help)
      show_help="true"
      ;;
    --verbose)
      export SXS_VERBOSE="true"
      ;;
    --version)
      cat << EOF
html_to_img v1.0

Copyright (c) 2021 Tin Lai (@soraxas)
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Written by Tin Lai (@soraxas)
EOF
      exit
      ;;
    *)
      # set back any unused args
      set -- "$@" "$arg"
  esac
done


if [ "$#" -ne 1 ] || [ -n "$show_help" ]; then
	printf '%s\n' "Usage: $(basename "$0") <URL|html_file|md_file>" >&2
	printf '\n' >&2
	printf '\t%s\n' "Uses chrome to render the given file/url to image." >&2
	printf '\t%s\n' "If a local markdown file is given, it will first" >&2
	printf '\t%s\n' "be converted to a html using pandoc before" >&2
	printf '\t%s\n' "rendering." >&2
	printf '\n' >&2
	printf '\t%s\n' "If a pipe exists, this script outputs the Base64" >&2
	printf '\t%s\n' "encoded image directly to stdout. Otherwise, the" >&2
	printf '\t%s\n' "stdout will output a message containing the filename." >&2
  exit 1
fi

input_file="$1"

if [ -f "$1" ]; then
  case "$1" in
    # for md file, first convert them to a html file using pandoc
    *.md)
      input_file="$(mktemp --suffix=.html)"
      pandoc "$1" -o "$input_file"

      # insert the base directory tag to the beginning of the html
      # for images in realted path
      basedir_tag="<base href=\"$(realpath "$1")\">"
      sed -i '1s$^$'"$basedir_tag"'\n$' "$input_file"
      ;;
      
  esac
fi


tmp_file="$(mktemp)"

cmd="$(echo google-chrome --headless --hide-scrollbars "--screenshot=$tmp_file" --window-size=800,1024 --disable-gpu "$input_file")"

#verbose=true
if [ -n "$verbose" ]; then
  $cmd 1>&2
else
  $cmd >/dev/null 2>&1 
fi

#echo $tmp_file

if [ -t 1 ]; then
  echo "Saved to $tmp_file"
  echo "(You can pipe the output to display image directly)"
else
  # inside a pipe
  cat "$tmp_file"
fi

