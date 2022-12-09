#!/bin/bash

has_cmd() {
  command -v "$1" >/dev/null
}

# get a chrome binary that exists
for bin in google-chrome google-chrome-stable; do
  if has_cmd "$bin"; then
    GOOGLE_CHROME_BINARY="$bin"
    break
  fi
done
if [ -z "$GOOGLE_CHROME_BINARY" ]; then
  echo "No google chrome binary found."
  exit 1
fi

set -e
#set -x

filelist=()

width=800
height=1024
while test $# -gt 0; do
    case "$1" in
      -w|--width)
        shift
        width="$1"
        ;;
      -h|--height)
        shift
        height="$1"
        ;;
      --no-auto-display)
        no_auto_display="true"
        ;;
      --help)
        show_help="true"
        ;;
      -v|--verbose)
        export SXS_VERBOSE="true"
        set -x
        ;;
      --version)
        cat << EOF
html_to_img v1.2

Copyright (c) 2021 Tin Lai (@soraxas)
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Written by Tin Lai (@soraxas)
EOF
      exit
      ;;
      *)
        # set to file list
        filelist+=("$1")
        #set -- "$filelist" "$arg"
    esac
    shift
    if [ -n "$breaknow" ]; then
      break
    fi
done


if [ "${#filelist[@]}" -lt 1 ] || [ -n "$show_help" ]; then
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
  printf '\n' >&2
  printf '%s\n' "Options:" >&2
	printf '\t%s\t%s\n' "--help" "display help message" >&2
	printf '\t%s\t%s\n' "--verson" "display version information" >&2
	printf '\t%s\t%s\n' "-v, --verbose" "be verbose and for debug" >&2
	printf '\t%s\t%s\n' "--verson" "display version information" >&2
  printf '\t%s\t%s\n' "-w, --width" "set width of rendering browser (default: 800)" >&2
  printf '\t%s\t%s\n' "-h, --height" "set height of rendering browser (default: 1024)" >&2
	printf '\t%s\t%s\n' "--no-auto-display" "" >&2
	printf '\t\t\t%s\n' "do not attempt to automatically display" >&2
	printf '\t\t\t%s\n' "the picture" >&2
  exit 1
fi

#input_file="$1"
input_file="${filelist[0]}"

if [ -f "$input_file" ]; then
  case "$input_file" in
    # for md file, first convert them to a html file using pandoc
    *.md|*.markdown)
      to_be_converted="$input_file"
      input_file="$(mktemp --suffix=.html)"
      pandoc "$to_be_converted" -o "$input_file"

      # insert the base directory tag to the beginning of the html
      # for images in realted path
      basedir_tag="<base href=\"$(realpath "$to_be_converted")\">"
      sed -i '1s$^$'"$basedir_tag"'\n$' "$input_file"
      ;;
      
  esac
else
  printf '%s\n' "File '$input_file' does not exists!"
  exit 1
fi

requested_output_file="${filelist[1]}"
if [ -z "$requested_output_file" ]; then
  output_file="$(mktemp)"
else
  output_file="$requested_output_file"
fi

cmd="'$GOOGLE_CHROME_BINARY' --headless --hide-scrollbars --screenshot='$output_file' --window-size='$width,$height' --disable-gpu '$input_file'"

#verbose=true
if [ -n "$verbose" ]; then
  eval "$cmd" 1>&2
else
  eval "$cmd" >/dev/null 2>&1 
fi

#echo $output_file
if [ -z "$requested_output_file" ]; then
  if [ -t 1 ]; then
    if [ -z "$no_auto_display" ]; then
      # try to automatically use supported method to display output
      if has_cmd timg; then
        to_pipe="timg -"
      elif has_cmd kitty; then
        to_pipe="kitty +kitten icat"
      fi
    fi
    if [ -n "$to_pipe" ]; then
      cat "$output_file" | $to_pipe
    else
      echo "Saved to $output_file"
      echo "(You can pipe the output to display image directly)"
    fi
  else
    # inside a pipe
    cat "$output_file"
  fi
fi
