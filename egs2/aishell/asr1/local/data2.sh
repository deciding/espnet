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
# non-commercial data, apply and download by yourself
# data_url=www.openslr.org/resources/33
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

if [ -z "${AISHELL2}" ]; then
  log "Error: \$AISHELL2 is not set in db.sh."
  exit 2
fi


# To absolute path
AISHELL2=$(cd ${AISHELL2}; pwd)

## unzip and untar
#ws=$(pwd)
#cd $AISHELL2
#unzip -d . $data_file_name
#cd ${data_dir_name}/data/wav/
#find . -name '*.tar.gz' -exec tar xzvf {} \;
#find . -name '*.tar.gz' -exec rm {} \;
#cd $ws

aishell_audio_dir=${AISHELL2}/${data_dir_name}/data/wav
aishell_text=${AISHELL2}/${data_dir_name}/data/trans.txt

log "Data Preparation"
train_dir=data_aishell2/local/train
tmp_dir=data_aishell2/local/tmp

mkdir -p $train_dir
mkdir -p $tmp_dir

# find wav audio file for train, dev and test resp.
find $aishell_audio_dir -iname "*.wav" > $tmp_dir/wav.flist
n=$(wc -l < $tmp_dir/wav.flist)
[ $n -ne 1009223 ] && \
  log Warning: expected 1009223 data data files, found $n

cat $tmp_dir/wav.flist > $train_dir/wav.flist || exit 1;

rm -r $tmp_dir

# Transcriptions preparation
dir=$train_dir
log Preparing $dir transcriptions
# wavname as uttid
#sed -e 's/\.wav//' $dir/wav.flist | awk -F '/' '{print $NF}' > $dir/utt.list
sed -e 's/\.wav//' $dir/wav.flist | awk -F '/' '{print substr($NF, 2)}' > $dir/utt.list
# wavdir as spkid
#sed -e 's/\.wav//' $dir/wav.flist | awk -F '/' '{i=NF-1;printf("%s %s\n",$NF,$i)}' > $dir/utt2spk_all
sed -e 's/\.wav//' $dir/wav.flist | awk -F '/' '{i=NF-1;printf("%s %s\n", substr($NF, 2),$i)}' > $dir/utt2spk_all
# wavname wavpath as wav.scp
paste -d' ' $dir/utt.list $dir/wav.flist > $dir/wav.scp_all
# wavnames are filter of the transcript
awk '{print substr($0, 2)}' $aishell_text > $dir/trans_org.txt
#utils/filter_scp.pl -f 1 $dir/utt.list $aishell_text > $dir/transcripts.txt
utils/filter_scp.pl -f 1 $dir/utt.list $dir/trans_org.txt > $dir/transcripts.txt
# above result is a join of wavnames and transcript, it will be used to update utt.list
awk '{print $1}' $dir/transcripts.txt > $dir/utt.list
utils/filter_scp.pl -f 1 $dir/utt.list $dir/utt2spk_all | sort -u > $dir/utt2spk
utils/filter_scp.pl -f 1 $dir/utt.list $dir/wav.scp_all | sort -u > $dir/wav.scp
sort -u $dir/transcripts.txt > $dir/text
utils/utt2spk_to_spk2utt.pl $dir/utt2spk > $dir/spk2utt

final_train_dir=data_aishell2/train
mkdir -p $final_train_dir

for f in spk2utt utt2spk wav.scp text; do
  cp $train_dir/$f $final_train_dir/$f || exit 1;
done

# remove space in text
#for x in train dev test; do
cp $final_train_dir/text $final_train_dir/text.org
paste -d " " <(cut -f 1 -d$'\t' $final_train_dir/text.org) <(cut -f 2- -d$'\t' $final_train_dir/text.org | tr -d " ") \
  > $final_train_dir/text
rm $final_train_dir/text.org
#done

log "Successfully finished. [elapsed=${SECONDS}s]"
