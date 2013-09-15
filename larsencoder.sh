#!/bin/bash
# dpxderiver.sh
# author: dave rice dave@dericed.com
# description: This is a very specific script intended to take a collection of DPX images and a WAV audio file as an input and then create multiple derivatives using ffmbc and libx264
# dependencies: The script expects to use ffmpeg version 1.1 or higher compiled with libx264 and libfaac. The system must contain two libx264 builds, one configured with --bit-depth=8 and one with --bit-depth=10.  The LD_LIBRARY_PATH (or DYLD_LIBRARY_PATH on Mac) will be adjusted within the script to point to the needed library.
# testing: If you need to generate sample files for testing this script I recommend making them via:
# ffmpeg -f lavfi -i testsrc=s=1920x1080:d=10:r=ntsc-film -start_number 100000 tmpdpxpath/images/%06d.dpx
# ffmpeg -f lavfi -i aevalsrc="sin(440*2*PI*t):cos(430*2*PI*t)::c=stereo:s=48000:d=10" -c pcm_s24le tmpdpxpath/audio/1.wav

x264_8bit_library_path=/tmp
ffmpeg_8="/usr/local/bin/ffmpeg" # refer to ffmpeg compiled with 8-bit libx264 support
ffmpeg_10="/usr/local/bin/ffmpegx10" # refer to ffmpeg compiled with 10-bit libx264 support

tmpdpxpath=~/tmpdpxpath
output_options_dnxhd_dir="$tmpdpxpath/dnxhd"
output_options_dnxhd_name="dnxhd.mov"

# presumed variables
imagepath="$tmpdpxpath/images"
audiopath="$tmpdpxpath/audio"
logspath="$tmpdpxpath/logs"
firstimagefile=`find "$imagepath" -type f \( -name '*.dpx' -o -name '*.DPX' \) | head -n 1`
start_number=`echo $(basename "$firstimagefile") | sed "s/[^0-9]//g;s/^$/-1/;"`
patternfilename=`echo "$firstimagefile" | sed "s/${start_number}/%06d/"`
[ -z "$start_number" ] && { echo ERROR Unable to discover number pattern of the filenames ; exit 1 ;};
audiofile="$audiopath/1.wav"
overwrite_outputs=" -y " # must equal " -y " to overwrite outputs, " -n " to skip any operation that would overwrite, or " " to prompt to user to decide

if [ -f "$audiofile" ] ; then
  hasaudio='y'
else
  hasaudio='n'
fi

# variable for dpx input
input_options=" -start_number $start_number "
input_options+=" -r ntsc-film "

# dnxhd output options
output_options_dnxhd_dir="$tmpdpxpath/dnxhd"
output_options_dnxhd_name="dnxhd.mov"
output_options_dnxhd_v=" -c:v dnxhd "
output_options_dnxhd_v+=" -pix_fmt yuv422p10le "
output_options_dnxhd_v+=" -s 1920x1080 "
output_options_dnxhd_v+=" -b:v 175M "
output_options_dnxhd_v+=" -r ntsc-film "
[ "$hasaudio" = "y" ] && { audioinput=" -i '$audiofile' " ; output_options_dnxhd_a=" -c:a copy " ;};

# streaming output options
output_options_streaming_dir="$tmpdpxpath/streaming"
output_options_streaming_name="streaming.mp4"
output_options_streaming_v=" -c:v libx264 "
output_options_streaming_v+=" -pix_fmt yuv420p "
output_options_streaming_v+=" -s hd480 "
output_options_streaming_v+=" -b:v 1.5M "
[ "$hasaudio" = "y" ] && { audioinput=" -i '$audiofile' " ; output_options_streaming_a=" -c:a libfaac " ;};

# lossless output options
output_options_lossless_dir="$tmpdpxpath/lossless"
output_options_lossless_name="lossless.mp4"
output_options_lossless_v=" -c:v libx264 "
output_options_lossless_v+=" -pix_fmt yuv422p10le "
output_options_lossless_v+=" -qp 0 " # force constant QT, 0=lossless
[ "$hasaudio" = "y" ] && { audioinput=" -i '$audiofile' " ; output_options_lossless_a=" -c:a libfaac " ;};

# check for required directories (possibly create missing output directories)
[ -d "$tmpdpxpath" ] || { echo "Error: $tmpdpxpath is not found" ; exit 1 ; };
[ -d "$imagepath" ] || { echo "Error: $imagepath is not found" ; exit 1 ; };
[ -d "$audiopath" ] || { echo "Error: $audiopath is not found" ; exit 1 ; };
[ -d "$logspath" ] || { mkdir -p "$logspath" || { echo "Error: Can not create $logspath" ; exit 1 ; }; };
[ -d "$output_options_dnxhd_dir" ] || { mkdir -p "$output_options_dnxhd_dir" || { echo "Error: Can not create $output_options_dnxhd_dir" ; exit 1 ; }; };
[ -d "$output_options_streaming_dir" ] || { mkdir -p "$output_options_streaming_dir" || { echo "Error: Can not create $output_options_streaming_dir" ; exit 1 ; }; };
[ -d "$output_options_lossless_dir" ] || { mkdir -p "$output_options_lossless_dir" || { echo "Error: Can not create $output_options_lossless_dir" ; exit 1 ; }; };

# check for minimal required files
[ -r "$firstimagefile" ] || { echo "Error: $firstimagefile is not found or not readable" ; exit 1 ; };

export FFREPORT="file=$logspath/%p_%t_convert-to-dnxhd_and_streaming.log"
dnxhd_cmd="$ffmpeg_8 $overwrite_outputs $input_options -i '$patternfilename' $audioinput $output_options_dnxhd_v $output_options_dnxhd_a '$output_options_dnxhd_dir/$output_options_dnxhd_name' $output_options_streaming_v $output_options_streaming_a '$output_options_streaming_dir/$output_options_streaming_name'"
echo "$dnxhd_cmd"
eval "$dnxhd_cmd"

# need to switch from ffmpeg compiled with 8 bit x264 to the 10 bit version in here somewhere.

export FFREPORT="file=$logspath/%p_%t_convert-to-lossless_yuv422p10le_libx264.log"
lossless_cmd="$ffmpeg_10 $overwrite_outputs $input_options -i '$patternfilename' $audioinput $output_options_lossless_v $output_options_lossless_a '$output_options_lossless_dir/$output_options_lossless_name'"
echo "$lossless_cmd"
eval "$lossless_cmd"
echo DONE