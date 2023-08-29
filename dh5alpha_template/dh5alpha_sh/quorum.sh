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
START_TIME=$(date +%s)

# Add masurca to $PATH
export PATH="$(readlinkf "$(which masurca)" | xargs dirname):$PATH"

#----------------------------#
# Renaming reads
#----------------------------#
log_info 'Processing pe and/or se library reads'

faops interleave \
    -q -p pe \
    'R1.fq.gz' \
    'R2.fq.gz' \
    > 'pe.renamed.fastq'

faops interleave \
    -q -p se \
    'Rs.fq.gz' \
    > 'se.renamed.fastq'

#----------------------------#
# Stats of reads
#----------------------------#
head -n 80000 pe.renamed.fastq > pe_data.tmp

KMER=$(
    tail -n 40000 pe_data.tmp |
        perl -e '
            my @lines;
            while ( my $line = <> ) {
                $line = <>;
                chomp($line);
                push( @lines, $line );
                $line = <>;
                $line = <>;
            }
            my @legnths;
            my $min_len    = 100000;
            my $base_count = 0;
            for my $l (@lines) {
                $base_count += length($l);
                push( @lengths, length($l) );
                for $base ( split( "", $l ) ) {
                    if ( uc($base) eq "G" or uc($base) eq "C" ) { $gc_count++; }
                }
            }
            @lengths  = sort { $b <=> $a } @lengths;
            $min_len  = $lengths[ int( $#lengths * .75 ) ];
            $gc_ratio = $gc_count / $base_count;
            $kmer     = 0;
            if ( $gc_ratio < 0.5 ) {
                $kmer = int( $min_len * .7 );
            }
            elsif ( $gc_ratio >= 0.5 && $gc_ratio < 0.6 ) {
                $kmer = int( $min_len * .5 );
            }
            else {
                $kmer = int( $min_len * .33 );
            }
            $kmer++ if ( $kmer % 2 == 0 );
            $kmer = 31  if ( $kmer < 31 );
            $kmer = 127 if ( $kmer > 127 );
            print $kmer;
    ' )
save KMER
log_debug "Choosing kmer size of $KMER"

MIN_Q_CHAR=$(
    head -n 40000 pe_data.tmp |
        awk 'BEGIN{flag=0}{if($0 ~ /^\+/){flag=1}else if(flag==1){print $0;flag=0}}' |
        perl -ne '
            BEGIN { $q0_char = "@"; }

            chomp;
            for $v ( split "" ) {
                if ( ord($v) < ord($q0_char) ) { $q0_char = $v; }
            }

            END {
                $ans = ord($q0_char);
                if   ( $ans < 64 ) { print "33\n" }
                else               { print "64\n" }
            }
    ')
save MIN_Q_CHAR
log_debug "MIN_Q_CHAR: $MIN_Q_CHAR"

#----------------------------#
# Error correct reads
#----------------------------#
JF_SIZE=$(
    ls -l *.fastq |
        awk '{n+=$5} END{s=int(n / 50 * 1.1); if(s>500000000)print s;else print "500000000";}'
)
perl -e '
    if(int('$JF_SIZE') > 500000000) {
        print "WARNING: JF_SIZE set too low, increasing JF_SIZE to '$JF_SIZE'.\n";
    }
    '

log_info Creating mer database for Quorum.
quorum_create_database \
    -t 12 \
    -s $JF_SIZE -b 7 -m 24 -q $((MIN_Q_CHAR + 5)) \
    -o quorum_mer_db.jf.tmp \
    pe.renamed.fastq se.renamed.fastq \
    && mv quorum_mer_db.jf.tmp quorum_mer_db.jf
if [ $? -ne 0 ]; then
    log_warn Increase JF_SIZE by --jf, the recommendation value is genome_size*coverage/2
    exit 1
fi

# -m Minimum count for a k-mer to be considered "good" (1)
# -g Number of good k-mer in a row for anchor (2)
# -a Minimum count for an anchor k-mer (3)
# -w Size of window (10)
# -e Maximum number of error in a window (3)
# As we have trimmed reads with sickle, we lower `-e` to 1 from original value of 3,
# remove `--no-discard`.
# And we only want most reliable parts of the genome other than the whole genome, so dropping rare
# k-mers is totally OK for us. Raise `-m` from 1 to 3, `-g` from 1 to 3, and `-a` from 1 to 4.
log_info Error correct reads.
quorum_error_correct_reads \
    -q $((MIN_Q_CHAR + 40)) \
    -m 3 -s 1 -g 3 -a 4 -t 12 -w 10 -e 1 \
    quorum_mer_db.jf \
    pe.renamed.fastq se.renamed.fastq \
    -o R.cor --verbose 1>quorum.err 2>&1 \
|| {
    mv R.cor.fa R.cor.fa.failed;
    log_warn Error correction of reads failed.;
    exit 1;
}

log_debug "Discard any reads with subs"
mv R.cor.fa R.cor.sub.fa

# The quorum appended string styled is 42:sub:C-T or 43:3_trunc
cat R.cor.sub.fa |
    grep ':sub:' |
    perl -nl -e '/^>([\w\/]+)/ and print $1' \
    > R.discard.lst
cat R.cor.sub.fa |
    grep 'trunc' |
    perl -nl -e '/^>([\w\/]+)/ and print $1' \
    >> R.discard.lst

faops some -i -l 0 R.cor.sub.fa R.discard.lst stdout \
    > R.cor.fa

rm R.cor.sub.fa

#----------------------------#
# Estimating genome size.
#----------------------------#
log_info Estimating genome size.

jellyfish count -m 31 -t 12 -C -s $JF_SIZE -o k_u_hash_0 R.cor.fa
ESTIMATED_GENOME_SIZE=$(
    jellyfish histo -t 12 -h 1 k_u_hash_0 |
        tail -n 1 |
        awk '{print $2}'
)
save ESTIMATED_GENOME_SIZE
log_debug "Estimated genome size: $ESTIMATED_GENOME_SIZE"

log_debug "Reads stats with faops"
SUM_IN=$( faops n50 -H -N 0 -S pe.renamed.fastq se.renamed.fastq )
save SUM_IN
SUM_OUT=$( faops n50 -H -N 0 -S R.cor.fa )
save SUM_OUT

#----------------------------#
# Shuffle interleaved reads.
#----------------------------#
log_info Shuffle interleaved reads.
mv R.cor.fa R.interleave.fa
cat R.interleave.fa |
    awk '{
        OFS="\t"; \
        getline seq; \
        getline name2; \
        getline seq2; \
        print $0,seq,name2,seq2}' |
    tsv-sample |
    awk '{OFS="\n"; print $1,$2,$3,$4}' \
    > R.cor.fa
rm R.interleave.fa
pigz -p 12 R.cor.fa

#----------------------------#
# Done.
#----------------------------#
find . -type f -name "quorum_mer_db.jf" | parallel --no-run-if-empty -j 1 rm
find . -type f -name "k_u_hash_0"       | parallel --no-run-if-empty -j 1 rm
find . -type f -name "*.tmp"            | parallel --no-run-if-empty -j 1 rm
find . -type f -name "pe.renamed.fastq" | parallel --no-run-if-empty -j 1 rm
find . -type f -name "se.renamed.fastq" | parallel --no-run-if-empty -j 1 rm
find . -type f -name "pe.cor.sub.fa"    | parallel --no-run-if-empty -j 1 rm
find . -type f -name "*.cor.log"        | parallel --no-run-if-empty -j 1 rm

save START_TIME

END_TIME=$(date +%s)
save END_TIME

RUNTIME=$((END_TIME-START_TIME))
save RUNTIME

log_info Done.

exit 0
