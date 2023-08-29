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

## 计算insert size的分布
log_warn 2_insert_size.sh

mkdir -p 2_illumina/insert_size
cd 2_illumina/insert_size

for PREFIX in R S T; do
    if [ ! -e ../${PREFIX}1.fq.gz ]; then
        continue;
    fi

    if [ -e ${PREFIX}.ihist.tadpole.txt ]; then
        continue;
    fi

    ## tadpole.sh，reads组装成contigs
    ## Use kmer counts to assemble contigs
    tadpole.sh \
        in=../${PREFIX}1.fq.gz \
        in2=../${PREFIX}2.fq.gz \
        out=${PREFIX}.tadpole.contig.fasta \
        threads=12 \
        overwrite 
    ## in=<file>，Primary input file for reads to use as kmer data.
    ## in2=<file>，Second input file for paired data.
    ## out=<file>，Write contigs (in contig mode) or corrected/extended reads (in other modes).
    ## threads=X，Spawn X hashing threads (default is number of logical processors).

    ## 修改contigs的名称和格式
    cat ${PREFIX}.tadpole.contig.fasta |
        faops dazz -l 0 -p T stdin stdout \
        > ${PREFIX}.tadpole.contig.fa
    ## -l INT，sequence line length [80]
    ## -p STR，prefix of names [read]

    ## bbmap.sh，将reads比对的contigs上(建立索引，序列比对)
    ## Fast and accurate splice-aware read aligner
    bbmap.sh \
        in=../${PREFIX}1.fq.gz \
        in2=../${PREFIX}2.fq.gz \
        out=${PREFIX}.tadpole.sam.gz \
        ref=${PREFIX}.tadpole.contig.fa \
        threads=12 \
        pairedonly \
        reads=1000000 \
        nodisk overwrite
    ## bbmap.sh ref=<reference fasta> in=<reads> out=<output sam> nodisk
    ## in=<file>，Primary reads input; required parameter.
    ## in2=<file>，For paired reads in two files.
    ## out=<file>，Write all reads to this file.
    ## ref=<file>，Specify the reference sequence. Only do this ONCE, when building the index (unless using 'nodisk').
    ## threads=auto，(t) Set to number of threads desired. By default, uses all cores available.
    ## pairedonly=f，(po) Treat unpaired reads as unmapped. Thus they will be sent to 'outu' but not 'outm'.
    ## reads=-1，Set to a positive number N to only process the first N reads (or pairs), then quit.  -1 means use all reads.
    ## nodisk=f，Set to true to build index in memory and write nothing to disk except output.
    ## overwrite=f，(ow) Allow process to overwrite existing files.

    ## reformat.sh，统计reads的大小
    ## Reformats reads to change ASCII quality encoding, interleaving, file format, or compression format
    reformat.sh \
        in=${PREFIX}.tadpole.sam.gz \
        ihist=${PREFIX}.ihist.tadpole.txt \
        overwrite
    ## ihist=<file>，Insert size histograms. Requires paired reads interleaved in sam file.
    ## ow=f，(overwrite) Overwrites files that already exist.

    ## 对比对序列进行排序
    ## This tool sorts the input SAM or BAM file by coordinate, queryname (QNAME), or some other property of the SAM record.
    picard SortSam \
        -I ${PREFIX}.tadpole.sam.gz \
        -O ${PREFIX}.tadpole.sort.bam \
        --SORT_ORDER coordinate \
        --VALIDATION_STRINGENCY LENIENT
    ## --INPUT,-I <File>，The SAM, BAM or CRAM file to sort. Required.
    ## --OUTPUT,-O <File>，The sorted SAM, BAM or CRAM output file. Required.
    ## --SORT_ORDER,-SO <SortOrder>，Sort order of output file. Required.
    ## --VALIDATION_STRINGENCY <ValidationStringency>，Validation stringency for all SAM files read by this program.

    ## 统计reads的大小，绘制大小分布柱形图
    ## Collect metrics about the insert size distribution of a paired-end library.
    picard CollectInsertSizeMetrics \
        -I ${PREFIX}.tadpole.sort.bam \
        -O ${PREFIX}.insert_size.tadpole.txt \
        --Histogram_FILE ${PREFIX}.insert_size.tadpole.pdf
    ## --INPUT,-I <File>，Input SAM/BAM/CRAM file. Required.
    ## --OUTPUT,-O <File>，The file to write the output to. Required.
    ## --Histogram_FILE,-H <File>，File to write insert size Histogram chart to. Required.

    ## 以参考基因组为参考
    if [ -e ../../1_genome/genome.fa ]; then
        bbmap.sh \
            in=../${PREFIX}1.fq.gz \
            in2=../${PREFIX}2.fq.gz \
            out=${PREFIX}.genome.sam.gz \
            ref=../../1_genome/genome.fa \
            threads=12 \
            maxindel=0 strictmaxindel \
            reads=1000000 \
            nodisk overwrite
        ## maxindel=16000，Don't look for indels longer than this. Lower is faster. Set to >=100k for RNAseq with long introns like mammals.
        ## strictmaxindel=f，When enabled, do not allow indels longer than 'maxindel'. By default these are not sought, but may be found anyway.

        reformat.sh \
            in=${PREFIX}.genome.sam.gz \
            ihist=${PREFIX}.ihist.genome.txt \
            overwrite

        picard SortSam \
            -I ${PREFIX}.genome.sam.gz \
            -O ${PREFIX}.genome.sort.bam \
            --SORT_ORDER coordinate

        picard CollectInsertSizeMetrics \
            -I ${PREFIX}.genome.sort.bam \
            -O ${PREFIX}.insert_size.genome.txt \
            --Histogram_FILE ${PREFIX}.insert_size.genome.pdf
    fi

    ## 清除中间文件，*.sam.gz和*.sort.bam
    find . -name "${PREFIX}.*.sam.gz" -or -name "${PREFIX}.*.sort.bam" |
        parallel --no-run-if-empty -j 1 rm
done

echo -e "Table: statInsertSize\n" > statInsertSize.md
printf "| %s | %s | %s | %s | %s |\n" \
    "Group" "Mean" "Median" "STDev" "PercentOfPairs/PairOrientation" \
    >> statInsertSize.md
printf "|:--|--:|--:|--:|--:|\n" >> statInsertSize.md

# bbtools reformat.sh
#Mean	339.868
#Median	312
#Mode	251
#STDev	134.676
#PercentOfPairs	36.247
for PREFIX in R S T; do
    for G in genome tadpole; do
        if [ ! -e ${PREFIX}.ihist.${G}.txt ]; then
            continue;
        fi

        printf "| %s " "${PREFIX}.${G}.bbtools" >> statInsertSize.md
        cat ${PREFIX}.ihist.${G}.txt |
            perl -nla -e '
                BEGIN { our $stat = { }; }; ## 初始化哈希$stat

                m{\#(Mean|Median|STDev|PercentOfPairs)} or next; ## 正则表达式匹配标题行
                $stat->{$1} = $F[1]; ## 赋值

                END {
                    printf qq{| %.1f | %s | %.1f | %.2f%% |\n},
                        $stat->{Mean},
                        $stat->{Median},
                        $stat->{STDev},
                        $stat->{PercentOfPairs};
                }
                ' \
            >> statInsertSize.md
    done
done

# picard CollectInsertSizeMetrics
#MEDIAN_INSERT_SIZE	MODE_INSERT_SIZE	MEDIAN_ABSOLUTE_DEVIATION	MIN_INSERT_SIZE	MAX_INSERT_SIZE	MEAN_INSERT_SIZE	STANDARD_DEVIATION	READ_PAIRS	PAIR_ORIENTATION	WIDTH_OF_10_PERCENT	WIDTH_OF_20_PERCENT	WIDTH_OF_30_PERCENT	WIDTH_OF_40_PERCENT	WIDTH_OF_50_PERCENT	WIDTH_OF_60_PERCENT	WIDTH_OF_70_PERCENT	WIDTH_OF_80_PERCENT	WIDTH_OF_90_PERCENT	WIDTH_OF_95_PERCENT	WIDTH_OF_99_PERCENT	SAMPLE	LIBRARY	READ_GROUP
#296	287	14	92	501	294.892521	21.587526	1611331	FR	7	11	17	23	29	35	41	49	63	81	145
for PREFIX in R S T; do
    for G in genome tadpole; do
        if [ ! -e ${PREFIX}.insert_size.${G}.txt ]; then
            continue;
        fi

        cat ${PREFIX}.insert_size.${G}.txt |
            GROUP="${PREFIX}.${G}" perl -nla -F"\t" -e '
                next if @F < 9;
                next unless /^\d/; ## 过滤掉标题行或非数字行
                printf qq{| %s | %.1f | %s | %.1f | %s |\n},
                    qq{$ENV{GROUP}.picard},
                    $F[5],
                    $F[0],
                    $F[6],
                    $F[8];
                ' \
            >> statInsertSize.md
    done
done

cat statInsertSize.md

mv statInsertSize.md ../../


bbmap.sh \
            in=../R1.fq.gz \
            in2=../R2.fq.gz \
            out=R.genome.sam.gz \
            ref=../../1_genome/genome.fa \
            threads=12 \
            maxindel=0 strictmaxindel \
            reads=1000000 \
            nodisk overwrite

reformat.sh \
            in=R.genome.sam.gz \
            ihist=R.ihist.genome.txt \
            overwrite

        picard SortSam \
            -I R.genome.sam.gz \
            -O R.genome.sort.bam \
            --SORT_ORDER coordinate

        picard CollectInsertSizeMetrics \
            -I ${PREFIX}.genome.sort.bam \
            -O ${PREFIX}.insert_size.genome.txt \
            --Histogram_FILE ${PREFIX}.insert_size.genome.pdf
    fi

