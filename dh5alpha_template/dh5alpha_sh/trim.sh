#!/usr/bin/env bash

BASH_DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

cd "${BASH_DIR}"

#----------------------------#
# Colors in term
#----------------------------#
# http://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
GREEN=
RED=
NC=
if tty -s < /dev/fd/1 2> /dev/null; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color
fi

log_warn () {
    echo >&2 -e "${RED}==> $@ <==${NC}"
}

log_info () {
    echo >&2 -e "${GREEN}==> $@${NC}"
}

log_debug () {
    echo >&2 -e "==> $@"
}

#----------------------------#
# helper functions
#----------------------------#
set +e

# set stacksize to unlimited
if [[ "$OSTYPE" != "darwin"* ]]; then
    ulimit -s unlimited
fi

signaled () {
    log_warn Interrupted
    exit 1
}
trap signaled TERM QUIT INT

# save environment variables
save () {
    printf ". + { %s: \"%s\"}" $1 $(eval "echo -n \"\$$1\"") > jq.filter.txt

    if [ -e env.json ]; then
        cat env.json |
            jq --sort-keys --from-file jq.filter.txt \
            > env.json.new
        rm env.json
    else
        jq --from-file jq.filter.txt --null-input \
            > env.json.new
    fi

    mv env.json.new env.json
    rm jq.filter.txt
}

stat_format () {
    echo $(faops n50 -H -N 50 -S -C $@) |
        perl -nla -MNumber::Format -e '
            printf qq(%d\t%s\t%d\n), $F[0], Number::Format::format_bytes($F[1], base => 1000,), $F[2];
        '
}

time_format () {
    echo $@ |
        perl -nl -e '
            sub parse_duration {
                use integer;
                sprintf("%d:%02d:%02d", $_[0]/3600, $_[0]/60%60, $_[0]%60);
            }
            print parse_duration($_);
        '
}

readlinkf () {
    perl -MCwd -l -e 'print Cwd::abs_path shift' "$1";
}

#----------------------------#
# Run
#----------------------------#
rm -f temp.fq.gz;

#----------------------------#
# Pipeline
#----------------------------#
# from bbmap/bbmap/pipelines/assemblyPipeline.sh

# Reorder reads for speed of subsequent phases
# As we're going to precess reads from different sources, don't dedupe here.
# 1. dedupe, Remove duplicate reads.
# 2. optical, mark or remove optical duplicates only. Normal Illumina names needed.
log_info "clumpify"
if [ ! -e clumpify.fq.gz ]; then
    clumpify.sh \
        in=../R1.fq.gz \
in2=../R2.fq.gz \
out=clumpify.fq.gz \
dedupe dupesubs=0 \
threads=12 -Xmx10g
fi
rm -f temp.fq.gz; ln -s clumpify.fq.gz temp.fq.gz


# Remove reads without high depth kmer
log_info "kmer cutoff with bbnorm.sh"
if [ ! -e highpass.fq.gz ]; then
    bbnorm.sh \
        in=temp.fq.gz \
        out=highpass.fq.gz \
        passes=1 bits=16 min=30 target=9999999 \
        threads=12 -Xmx10g
fi
rm temp.fq.gz; ln -s highpass.fq.gz temp.fq.gz


# Trim 5' adapters and discard reads with Ns
# Use bbduk.sh to quality and length trim the Illumina reads and remove adapter sequences
# 1. ftm = 5, right trim read length to a multiple of 5
# 2. k = 23, Kmer length used for finding contaminants
# 3. ktrim=r, Trim reads to remove bases matching reference kmers to the right
# 4. mink=7, look for shorter kmers at read tips down to 7 bps
# 5. hdist=1, hamming distance for query kmers
# 6. tbo, trim adapters based on where paired reads overlap
# 7. tpe, when kmer right-trimming, trim both reads to the minimum length of either
# 8. qtrim=r, trim read right ends to remove bases with low quality
# 9. trimq=15, regions with average quality below 15 will be trimmed.
# 10. minlen=60, reads shorter than 60 bps after trimming will be discarded.
log_info "trim with bbduk.sh"
if [ ! -e trim.fq.gz ]; then
    bbduk.sh \
        in=temp.fq.gz \
        out=trim.fq.gz \
        ref=/mnt/c/biodata/bga/anchr/dh5alpha/2_illumina/trim/illumina_adapters.fa \
        maxns=0 ktrim=r k=23 mink=11 hdist=1 tbo tpe \
        minlen=60 qtrim=r trimq=15 ftm=5 \
        stats=R.trim.stats.txt overwrite \
        tossbrokenreads=t \
        threads=12 -Xmx10g
fi
rm temp.fq.gz; ln -s trim.fq.gz temp.fq.gz

# Remove synthetic artifacts, spike-ins and 3' adapters by kmer-matching.
log_info "filter with bbduk.sh"
if [ ! -e filter.fq.gz ]; then
    bbduk.sh \
        in=temp.fq.gz \
        out=filter.fq.gz \
        ref=/mnt/c/biodata/bga/anchr/dh5alpha/2_illumina/trim/illumina_adapters.fa,/mnt/c/biodata/bga/anchr/dh5alpha/2_illumina/trim/sequencing_artifacts.fa, \
        k=27 cardinality \
        stats=R.filter.stats.txt overwrite \
        tossbrokenreads=t \
        threads=12 -Xmx10g
fi
rm temp.fq.gz; ln -s filter.fq.gz temp.fq.gz

log_info "kmer histogram and peaks"
if [ ! -e peaks.final.txt ]; then
    kmercountexact.sh \
        in=temp.fq.gz \
        khist=R.khist.txt peaks=R.peaks.txt k=31 \
        threads=12 -Xmx10g
fi

# Revert to normal pair-end fastq files
log_info "re-pair with repair.sh"
if [ ! -e R1.trim.fq.gz ]; then
repair.sh \
        in=temp.fq.gz \
        out=R1.fq.gz \
        out2=R2.fq.gz \
        outs=Rs.fq.gz \
        repair \
        threads=12 -Xmx10g
fi

#----------------------------#
# Sickle
#----------------------------#
log_info "sickle ::: Qual 25 30 ::: Len 60"
parallel --no-run-if-empty --linebuffer -k -j 2 "
    mkdir -p Q{1}L{2}
    cd Q{1}L{2}

    printf '==> Qual-Len: %s\n'  Q{1}L{2}
    if [ -e R1.fq.gz ]; then
        echo '    R1.fq.gz already presents'
        exit;
    fi

sickle pe \
        -t sanger \
        -q {1} \
        -l {2} \
        -f ../R1.fq.gz \
        -r ../R2.fq.gz \
        -o R1.fq \
        -p R2.fq \
        -s Rs.fq
    sickle se \
        -t sanger \
        -q {1} \
        -l {2} \
        -f ../Rs.fq.gz \
        -o Rs.temp.fq
    cat Rs.temp.fq >> Rs.fq
    rm Rs.temp.fq
pigz *.fq
    " ::: 25 30 ::: 60

exit 0
