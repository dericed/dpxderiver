#!/bin/bash
# dpxderiver.sh
# author: dave rice dave@dericed.com
# description: This is a very specific script intended to take a collection of DPX images and a WAV audio file as an input and then create multiple derivatives using ffmbc and libx264
# dependencies: The script expects to use ffmpeg version 1.1 or higher compiled with libx264 and libfaac. Configure libx264 with either --bit-depth=8 or --bit-depth=10 as you wish.
# testing: If you need to generate sample files for testing this script I recommend making them via:
# ffmpeg -f lavfi -i testsrc=s=1920x1080:d=10:r=ntsc-film -start_number 100000 dpx_package_path/images/%06d.dpx
# ffmpeg -f lavfi -i aevalsrc="sin(440*2*PI*t):cos(430*2*PI*t)::c=stereo:s=48000:d=10" -c pcm_s24le dpx_package_path/audio/1.wav

usage(){
    echo
    echo "$(basename $0) ${version}"
    echo "Transcode DPX file sets to pre-determined outputs."
    echo "Usage: $(basename $0) package"
    echo " -h display this help"
    exit
}

# command-line options to set mediaid and original variables
OPTIND=1
while getopts ":h" opt; do
case "$opt" in
        h) usage ;;
        *) echo "bad option -$OPTARG" ; usage ;;
        :) echo "Option -$OPTARG requires an argument" ; exit 1 ;;
    esac
done
shift $(( ${OPTIND} - 1 ))

[ "$#" != 1 ] && usage
dpx_package_path="$1"
imagepath="$dpx_package_path/images"
audiopath="$dpx_package_path/audio"
[ -d "$dpx_package_path" ] || { echo "Error: $dpx_package_path is not found or is not a directory" ; usage ; };
[ -d "$imagepath" ] || { echo "Error: $imagepath is not found" ; exit 1 ; };
[ -d "$audiopath" ] || { echo "Error: $audiopath is not found" ; exit 1 ; };

# presumed variables
logspath="$dpx_package_path/logs"
output_options_dnxhd_dir="$dpx_package_path/dnxhd"
output_options_dnxhd_name="dnxhd.mov"
start_number="100000"
firstimagefile=$(find "$imagepath" -type f -iname "*${start_number}.dpx" | head -n 1)
patternfilename=$(echo "$firstimagefile" | sed "s/${start_number}/%06d/")
[ -z "$start_number" ] && { echo ERROR Unable to discover number pattern of the filenames ; exit 1 ;};
audiofile=$(find "$audiopath" -type f -iname '*.wav' | head -n 1)  # need to offset audio to match dpx from 10000
overwrite_outputs=" -y " # must equal " -y " to overwrite outputs, " -n " to skip any operation that would overwrite, or " " to prompt to user to decide

unset audioinput
unset output_options_dnxhd_v
unset output_options_dnxhd_a
unset output_options_lossless_v
unset output_options_lossless_a

if [ -f "$audiofile" ] ; then
hasaudio='y'
audioinput=(-i $audiofile)
output_options_dnxhd_a=(-c:a copy)
output_options_lossless_a=(-c:a copy)
else
hasaudio='n'
fi

if [ "$input_frame_rate" = "" ] ; then
echo "What frame rate should be used to interpret the input? "
    PS3="Selection? "
    select input_frame_rate in "12" "16" "18" "20" "22" "24000/1001" "24" "25" "30"
    do
        break
    done
fi

echo Selected frame rate is "$input_frame_rate"

# variable for dpx input
input_options="-start_number $start_number -r $input_frame_rate"

# dnxhd output options
output_options_dnxhd_dir="$dpx_package_path/dnxhd"
output_options_dnxhd_name="dnxhd.mov"

output_options_dnxhd_v+=(-c:v dnxhd)
output_options_dnxhd_v+=(-pix_fmt yuv422p10le)
output_options_dnxhd_v+=(-s 1920x1080)
output_options_dnxhd_v+=(-b:v 175M)
output_options_dnxhd_v+=(-r ntsc-film)

# lossless output options
output_options_lossless_dir="$dpx_package_path/lossless"
output_options_lossless_name="lossless.mov"
output_options_lossless_v=(-c:v libx264)
output_options_lossless_v+=(-pix_fmt yuv422p10le)
output_options_lossless_v+=(-qp 0) # force constant QT, 0=lossless
 
# check for required directories (possibly create missing output directories)
[ -d "$logspath" ] || { mkdir -p "$logspath" || { echo "Error: Can not create $logspath" ; exit 1 ; }; };
[ -d "$output_options_dnxhd_dir" ] || { mkdir -p "$output_options_dnxhd_dir" || { echo "Error: Can not create $output_options_dnxhd_dir" ; exit 1 ; }; };
[ -d "$output_options_lossless_dir" ] || { mkdir -p "$output_options_lossless_dir" || { echo "Error: Can not create $output_options_lossless_dir" ; exit 1 ; }; };
 
# check for minimal required files
[ -r "$firstimagefile" ] || { echo "Error: $firstimagefile is not found or not readable" ; exit 1 ; };
 
export FFREPORT="file=$logspath/%p_%t_convert-to-dnxhd_and_lossless_yuv422p10le_libx264.log"

ffmpeg $overwrite_outputs ${input_options} -i "$patternfilename" ${audioinput[@]} ${output_options_dnxhd_v[@]} ${output_options_dnxhd_a[@]} "$output_options_dnxhd_dir/$output_options_dnxhd_name" ${output_options_lossless_v[@]} ${output_options_lossless_a[@]} "$output_options_lossless_dir/$output_options_lossless_name"

echo DONE
