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
## 将masurca可执行文件的路径添加到环境变量中
export PATH="$(readlinkf "$(which masurca)" | xargs dirname):$PATH"
## 自定义函数readlinkf，用于获取指定路径的绝对路径

#----------------------------#
# Renaming reads
#----------------------------#
log_info 'Processing pe and/or se library reads'

## 修改序列前缀：pe（R1.fq.gz+R2.fq.gz=pe.renamed.fastq）
faops interleave \
    -q -p pe \
    'R1.fq.gz' \
    'R2.fq.gz' \
    > 'pe.renamed.fastq'
## -q，write FQ. The inputs must be FQs
## -p STR，prefix of names [read]

## 修改序列前缀：se（Rs.fq.gz=se.renamed.fastq）
faops interleave \
    -q -p se \
    'Rs.fq.gz' \
    > 'se.renamed.fastq'

#----------------------------#
# Stats of reads
#----------------------------#

head -n 80000 pe.renamed.fastq > pe_data.tmp
## FASTQ格式：label/sequence/+/Q scores(ASCⅡ)

## 确定kmer的大小
## kmer由GC含量和最小序列长度决定，且不为偶数，且31≤kmer≤127
## GC<0.5，$min_len*0.7
## 0.5≤GC<0.6，$min_len*0.5
## GC≥0.6，$min_len*0.33
KMER=$(
    tail -n 40000 pe_data.tmp |
        perl -e '
            my @lines;  ## 数组@lines, 储存序列本身
            while ( my $line = <> ) {  ## 读取第一行, label
                $line = <>;  ## 读取第二行, sequence
                chomp($line);
                push( @lines, $line );
                $line = <>;  ## 读取第三行, +
                $line = <>;  ## 读取第四行, Q scores
            }
            my @legnths;  ## 数组@legnths, 储存序列长度
            my $min_len    = 100000;  ## 初始化变量，最小序列长度
            my $base_count = 0;  ## 初始化变量，碱基总数
            for my $l (@lines) {
                $base_count += length($l);
                push( @lengths, length($l) );
                for $base ( split( "", $l ) ) {
                    if ( uc($base) eq "G" or uc($base) eq "C" ) { $gc_count++; }   ## 统计GC含量
                    ## Perl内置uc函数，转换为大写字母
                }
            }
            @lengths  = sort { $b <=> $a } @lengths; ## 降序排列
            $min_len  = $lengths[ int( $#lengths * .75 ) ]; ## $#lengths，数组最后一个元素的索引 ## $min_len取75%分位的值
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

## 确定最低质量值，33或64
MIN_Q_CHAR=$(
    head -n 40000 pe_data.tmp |
        awk 'BEGIN{flag=0}{if($0 ~ /^\+/){flag=1}else if(flag==1){print $0;flag=0}}' |
        ## 提取FASTQ格式的质量分数行
        perl -ne '
            BEGIN { $q0_char = "@"; }  ## 初始化变量

            chomp;
            for $v ( split "" ) {
                if ( ord($v) < ord($q0_char) ) { $q0_char = $v; }
                ## Perl内置函数ord，用于获取字符的ASCⅡ码
                ## @对应64
            }

            END {
                $ans = ord($q0_char);
                if   ( $ans < 64 ) { print "33\n" }  ## Phred+33 编码方式，33-126，Q=ASCII码值-33
                else               { print "64\n" }  ## Phred+64 编码方式，64-126，Q=ASCII码值-64
            }
    ')
save MIN_Q_CHAR

log_debug "MIN_Q_CHAR: $MIN_Q_CHAR"

#----------------------------#
# Error correct reads
#----------------------------#

## 调用Quorum
## 确定Jellyfish hash的大小，500MB
JF_SIZE=$(
    ls -l *.fastq | ## pe.renamed.fastq和se.renamed.fastq
        awk '{n+=$5} END{s=int(n / 50 * 1.1); if(s>500000000)print s;else print "500000000";}'
)
perl -e '
    if(int('$JF_SIZE') > 500000000) {
        print "WARNING: JF_SIZE set too low, increasing JF_SIZE to '$JF_SIZE'.\n";
    }
    '

log_info Creating mer database for Quorum.

## 创建数据库
quorum_create_database \
    -t 12 \
    -s $JF_SIZE -b 7 -m 24 -q $((MIN_Q_CHAR + 5)) \
    -o quorum_mer_db.jf.tmp \
    pe.renamed.fastq se.renamed.fastq \
    && mv quorum_mer_db.jf.tmp quorum_mer_db.jf
## Create database of k-mers for quorum error corrector
## -t, --threads=uint32，Number of threads (1)
## -s, --size=uint64，*Initial hash size
## -b, --bits=uint32，*Bits for value field
## -m, --mer=uint32，*Mer length
## -q, --min-qual-value=uint32，Min quality as an int
## -o, --output=path，Output file (combined_database)
## 检查退出状态码
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
## Error correct reads from a fastq file based on the k-mer frequencies
## -q, --qual-cutoff-value=uint32，Any base above with quality equal or greater is untouched when there are multiple choices 不受影响的碱基的最低质量Q
## -m, --min-count=uint32，Minimum count for a k-mer to be considered "good" (1) 被认为是good的kmer的最低计数
## -s, --skip=uint32，Number of bases to skip for start k-mer (1) 起始kmer跳过的碱基数
## -g, --good=uint32，Number of good k-mer in a row for anchor (2)  "anchr kmer"
## -a, --anchor-count=uint32，Minimum count for an anchor k-mer (3) "anchr kmer"的最低计数
## -t, --thread=uint32，Number of threads (1) 线程数
## -w, --window=uint32，Size of window (10) 窗口大小
## -e, --error=uint32，Maximum number of error in a window (3) 一个窗口内允许出现错误的最多数量
## -o, --output=prefix，Output file prefix (error_corrected)
## -v, --verbose，Be verbose (false) 详细输出
## -d, --no-discard，Do not discard reads, output a single N (false)

log_debug "Discard any reads with subs"
mv R.cor.fa R.cor.sub.fa

# The quorum appended string styled is 42:sub:C-T or 43:3_trunc
## 丢弃
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
## -i，Invert, output sequences not in the list
## -l INT，sequence line length [80]

rm R.cor.sub.fa

#----------------------------#
# Estimating genome size.
#----------------------------#
log_info Estimating genome size.

jellyfish count -m 31 -t 12 -C -s $JF_SIZE -o k_u_hash_0 R.cor.fa
## jellyfish count，Count k-mers in fasta or fastq files
## -m, --mer-len=uint32，*Length of mer
## -t, --threads=uint32，Number of threads (1)
## -C, --canonical，Count both strand, canonical representation (false)
## -s, --size=uint64，*Initial hash size
## -o, --output=string，Output file (mer_counts.jf)
ESTIMATED_GENOME_SIZE=$(
    jellyfish histo -t 12 -h 1 k_u_hash_0 |
        tail -n 1 |
        awk '{print $2}'
)
## jellyfish histo，Create an histogram of k-mer occurrences
## -h, --high=uint64，High count value of histogram (10000)

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
