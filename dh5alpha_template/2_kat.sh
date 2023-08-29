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
log_warn 2_kat.sh

mkdir -p 2_illumina/kat
cd 2_illumina/kat

for PREFIX in R S T; do
    if [ ! -e ../${PREFIX}1.fq.gz ]; then
        continue;
    fi

    if [ -e ${PREFIX}-gcp-31.mx.png ]; then
        continue;
    fi

    for KMER in 31 51 71; do
        log_info "PREFIX: ${PREFIX}; KMER: ${KMER}"

        kat hist \
            -t 12 -m ${KMER} \
            ../${PREFIX}1.fq.gz ../${PREFIX}2.fq.gz \
            -o ${PREFIX}-hist-${KMER}

        kat gcp \
            -t 12 -m ${KMER} \
            ../${PREFIX}1.fq.gz ../${PREFIX}2.fq.gz \
            -o ${PREFIX}-gcp-${KMER}
    done
done

find . -type f -name "*.mx" | parallel --no-run-if-empty -j 1 rm

echo -e "Table: statKAT\n" > statKAT.md

for PREFIX in R S T; do
    find . -type f -name "${PREFIX}-gcp*.dist_analysis.json" |
        sort |
        xargs cat |
        sed 's/%//g' |
        jq "{
            k: (\"${PREFIX}.\" + (.coverage.k | tostring)),
            mean_freq: .coverage.mean_freq,
            est_genome_size: .coverage.est_genome_size,
            est_het_rate: .coverage.est_het_rate,
            mean_gc: .gc.mean_gc,
        }"
done |
    mlr --ijson --otsv cat |
    perl -nla -F"\t" -e '
        /mean_gc/ and print and next;
        $F[3] = sprintf q(%.4f), $F[3];
        $F[4] = sprintf q(%.2f), $F[4];
        print join qq(\t), @F;
    ' |
    mlr --itsv --omd cat \
    >> statKAT.md

cat statKAT.md
mv statKAT.md ../../

exit 0

