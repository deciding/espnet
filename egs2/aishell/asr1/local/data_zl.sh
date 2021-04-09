#!/bin/bash
# For AISHELL2
# Set bash to 'debug' mode, it will exit on :
# -e 'error', -u 'undefined variable', -o ... 'error in pipeline', -x 'print commands',
set -e
set -u
set -o pipefail

log() {
    local fname=${BASH_SOURCE[1]##*/}
    echo -e "$(date '+%Y-%m-%dT%H:%M:%S') (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $*"
}
help_message=$(cat << EOF
Usage: $0

Options:
    --remove_archive (bool): true or false
      With remove_archive=True, the archives will be removed after being successfully downloaded and un-tarred.
EOF
)
SECONDS=0

# Data preparation related
data_url=https://www.openslr.org/resources/93/data_aishell3.tgz
data_file_name='ios.zip'
data_dir_name='iOS'

log "$0 $*"


. ./utils/parse_options.sh

. ./db.sh
. ./path.sh
. ./cmd.sh


if [ $# -gt 1 ]; then
  log "${help_message}"
  exit 2
fi

if [ -z "${AISHELL3}" ]; then
  log "Error: \$AISHELL3 is not set in db.sh."
  exit 2
fi


# To absolute path
#AISHELL3=$(cd ${AISHELL3}; pwd)
ZHAOLI=/workspace/ssd-asr/asr_test_zhaoli/ASR_Data_Zhaoli

## unzip and untar
#ws=$(pwd)
#cd $AISHELL3
#wget $data_url
#tar xzvf data_aishell3.tgz
#cd $ws

log "Data Preparation"
data_dir=data_zhaoli/
test_dir=$data_dir/local/test
tmp_dir=$data_dir/local/tmp

mkdir -p $test_dir
mkdir -p $tmp_dir

# find wav audio file for train, dev and test resp.
find $ZHAOLI -iname "*.wav" > $tmp_dir/wav.flist
n=$(wc -l < $tmp_dir/wav.flist)
[ $n -ne 13503 ] && \
  log Warning: expected 13503 data files, found $n


cp $tmp_dir/wav.flist $test_dir/wav.flist || exit 1;

rm -r $tmp_dir

# Transcriptions preparation
#for dset in train test; do
dset=test
dir=$data_dir/local/$dset
log Preparing $dir transcriptions
zhaoli_text=$ZHAOLI/text.txt
# wavname as uttid
sed -e 's/\.wav//' $dir/wav.flist | awk -F '/' '{iid=$NF;split(iid, fields, "-");printf "zhaoli%04d%03d\n", fields[1], fields[2]}' > $dir/utt.list
# wavdir as spkid
cat $dir/utt.list | awk '{printf("%s zhaoli\n",$0)}' > $dir/utt2spk_all
# wavname wavpath as wav.scp
paste -d' ' $dir/utt.list $dir/wav.flist > $dir/wav.scp_all
# wavnames are filter of the transcript
cat $zhaoli_text > $dir/trans_org.txt
#utils/filter_scp.pl -f 1 $dir/utt.list $zhaoli_text > $dir/transcripts.txt
utils/filter_scp.pl -f 1 $dir/utt.list $dir/trans_org.txt > $dir/transcripts.txt
# above result is a join of wavnames and transcript, it will be used to update utt.list
awk '{print $1}' $dir/transcripts.txt > $dir/utt.list
utils/filter_scp.pl -f 1 $dir/utt.list $dir/utt2spk_all | sort -u > $dir/utt2spk
utils/filter_scp.pl -f 1 $dir/utt.list $dir/wav.scp_all | sort -u > $dir/wav.scp
sort -u $dir/transcripts.txt > $dir/text
utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt

final_test_dir=data_zhaoli/test

mkdir -p $final_test_dir

for f in spk2utt utt2spk wav.scp text; do
  cp $test_dir/$f $final_test_dir/$f || exit 1;
done

# remove space in text
x=$final_test_dir
cp $x/text $x/text.org
paste -d " " <(cut -f 1 -d' ' $x/text.org) <(cut -f 2- -d' ' $x/text.org | tr -d " ") \
  > $x/text
rm $x/text.org

log "Successfully finished. [elapsed=${SECONDS}s]"
