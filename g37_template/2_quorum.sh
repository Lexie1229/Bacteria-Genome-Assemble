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
log_warn 2_quorum.sh

for Q in 0 25 30; do
    for L in 0 60; do
        cd ${BASH_DIR}

        if [ ! -d 2_illumina/Q${Q}L${L} ]; then
            continue;
        fi

        if [ -e 2_illumina/Q${Q}L${L}/pe.cor.fa.gz ]; then
            log_debug "2_illumina/Q${Q}L${L}/pe.cor.fa.gz presents"
            continue;
        fi

        START_TIME=$(date +%s)

        cd 2_illumina/Q${Q}L${L}

        for PREFIX in R S T; do
            if [ ! -e ${PREFIX}1.fq.gz ]; then
                continue;
            fi

            if [ -e ${PREFIX}.cor.fa.gz ]; then
                echo >&2 "    ${PREFIX}.cor.fa.gz exists"
                continue;
            fi

            log_info "Qual-Len: Q${Q}L${L}.${PREFIX}"

            anchr quorum \
                ${PREFIX}1.fq.gz \
${PREFIX}2.fq.gz \
                $(
                    if [ -s ${PREFIX}s.fq.gz ]; then
                        echo ${PREFIX}s.fq.gz;
                    fi
                ) \
-p 10 \
                --prefix ${PREFIX} \
                -o quorum.sh
            bash quorum.sh

            log_info "statQuorum.${PREFIX}"

            SUM_IN=$( cat env.json | jq '.SUM_IN | tonumber' )
            SUM_OUT=$( cat env.json | jq '.SUM_OUT | tonumber' )
            EST_G=$( cat env.json | jq '.ESTIMATED_GENOME_SIZE | tonumber' )
            SECS=$( cat env.json | jq '.RUNTIME | tonumber' )

            printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n" \
                "Q${Q}L${L}.${PREFIX}" \
                $( perl -e "printf qq(%.1f), ${SUM_IN} / 580076;" ) \
                $( perl -e "printf qq(%.1f), ${SUM_OUT} / 580076;" ) \
                $( perl -e "printf qq(%.2f%%), (1 - ${SUM_OUT} / ${SUM_IN}) * 100;" ) \
                $( cat env.json | jq '.KMER' ) \
                $( perl -MNumber::Format -e "print Number::Format::format_bytes(580076, base => 1000,);" ) \
                $( perl -MNumber::Format -e "print Number::Format::format_bytes(${EST_G}, base => 1000,);" ) \
                $( perl -e "printf qq(%.2f), ${EST_G} / 580076" ) \
                $( printf "%d:%02d'%02d''\n" $((${SECS}/3600)) $((${SECS}%3600/60)) $((${SECS}%60)) ) \
                > statQuorum.${PREFIX}

        done

        log_info "Combine Q${Q}L${L} .cor.fa.gz files"
        if [ -e S1.fq.gz ]; then
            gzip -d -c [RST].cor.fa.gz |
                awk '{
                    OFS="\t"; \
                    getline seq; \
                    getline name2; \
                    getline seq2; \
                    print $0,seq,name2,seq2}' |
                tsv-sample |
                awk '{OFS="\n"; print $1,$2,$3,$4}' \
                > pe.cor.fa
            pigz -p 10 pe.cor.fa
            rm [RST].cor.fa.gz
        else
            mv R.cor.fa.gz pe.cor.fa.gz
        fi

        rm env.json
        log_debug "Reads stats with faops"
        SUM_OUT=$( faops n50 -H -N 0 -S pe.cor.fa.gz )
        save SUM_OUT

        save START_TIME
        END_TIME=$(date +%s)
        save END_TIME
        RUNTIME=$((END_TIME-START_TIME))
        save RUNTIME

        # save genome size
        ESTIMATED_GENOME_SIZE=580076
        save ESTIMATED_GENOME_SIZE

    done
done

cd ${BASH_DIR}/2_illumina

if [ -e Q0L0/statQuorum.R ]; then
    echo -e "Table: statQuorum\n" > statQuorum.md
    printf "| %s | %s | %s | %s | %s | %s | %s | %s | %s |\n" \
        "Name" "CovIn" "CovOut" "Discard%" \
        "Kmer" "RealG" "EstG" "Est/Real" \
        "RunTime" \
        >> statQuorum.md
    printf "|:--|--:|--:|--:|--:|--:|--:|--:|--:|\n" \
        >> statQuorum.md

    for PREFIX in R S T; do
        for Q in 0 25 30; do
            for L in 0 60; do
                if [ -e Q${Q}L${L}/statQuorum.${PREFIX} ]; then
                    cat Q${Q}L${L}/statQuorum.${PREFIX} >> statQuorum.md;
                fi
            done
        done
    done

    cat statQuorum.md
    mv statQuorum.md ../
fi

log_info Done.

exit 0

