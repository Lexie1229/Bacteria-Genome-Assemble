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
log_info "clumpify"
clumpify.sh \
    in=../trim/R1.fq.gz \
in2=../trim/R2.fq.gz \
out=clumped.fq.gz \
    threads=12 -Xmx10g \
    dedupe dupesubs=0 \
    overwrite
log_info "clumpify SE"
clumpify.sh \
    in=../trim/Rs.fq.gz \
    out=clumpeds.fq.gz \
    threads=12 -Xmx10g \
    dedupe dupesubs=0 \
    overwrite
cat clumpeds.fq.gz >> clumped.fq.gz
rm clumpeds.fq.gz
rm -f temp.fq.gz; ln -s clumped.fq.gz temp.fq.gz

log_info Error-correct phase 1

# Error-correct phase 1
# error-correct via overlap
## 基于overlap，对reads进行纠错
bbmerge.sh \
    in=temp.fq.gz out=ecco.fq.gz \
    ihist=M.ihist.merge1.txt \
    threads=12 -Xmx10g \
ecco mix vstrict overwrite
rm temp.fq.gz; ln -s ecco.fq.gz temp.fq.gz
## bbmerge.sh，Merges paired reads into single reads by overlap detection.
## ihist=<file>，(hist) Insert length histogram output file. 生成insert size的分布直方图
## ecco=f，Error-correct the overlapping part, but don't merge.
## mix=f，Output both the merged (or mergable) and unmerged reads in the same file (out=).  Useful for ecco mode.
## verystrict=f，(vstrict) Greatly decrease FP and merging rate.
## 不进行paired reads的合并，并将可合并的reads和不可合并的reads输出到同一文件中

log_info Error-correct phase 2

# Error-correct phase 2
## 基于聚类，对reads进行纠错
clumpify.sh \
    in=temp.fq.gz out=eccc.fq.gz \
    threads=12 -Xmx10g \
    passes=4 ecc unpair repair overwrite
rm temp.fq.gz; ln -s eccc.fq.gz temp.fq.gz
## clumpify.sh，Sorts sequences to put similar reads near each other.
## passes=1，Use this many error-correction passes. 6 passes are suggested. 指定数据处理次数
## ecc=f，Error-correct reads. Requires multiple passes for complete correction. reads纠错
## unpair=f，For paired reads, clump all of them rather than just read 1. Destroys pairing. Without this flag, for paired reads, only read 1 will be error-corrected. 确保read1和read2均被聚类和纠错
## repair=f，After clumping and error-correction, restore pairing. 聚类和纠错后，重新配对

log_info Error-correct phase 3

# Error-correct phase 3
# Low-depth reads can be discarded here with the "tossjunk", "tossdepth", or "tossuncorrectable" flags.
# For large genomes, tadpole and bbmerge (during the "Merge" phase) may need the flag
# "prefilter=1" or "prefilter=2" to avoid running out of memory.
# "prefilter" makes these take twice as long though so don't use it if you have enough memory.
## 基于kmer，对reads进行纠错
tadpole.sh \
    in=temp.fq.gz out=ecct.fq.gz \
    threads=12 -Xmx10g \
ecc tossjunk tossdepth=2 tossuncorrectable overwrite
rm temp.fq.gz; ln -s ecct.fq.gz temp.fq.gz
## tadpole.sh，Uses kmer counts to assemble contigs, extend sequences, or error-correct reads.
## ecc=f，Error correct via kmer counts.
## tossjunk=f，Remove reads that cannot be used for assembly. 删除不能用于组装的reads
## tossdepth=-1，Remove reads containing kmers at or below this depth. Pairs are removed if either read fails. 删除深度小于特定值的reads
## tossuncorrectable，(tu) Discard reads containing uncorrectable errors. Requires error-correction to be enabled. 去除包含不可纠正错误的reads

log_info "Read extension"

## 延伸序列
tadpole.sh \
    in=temp.fq.gz out=extended.fq.gz \
    threads=12 -Xmx10g \
mode=extend el=20 er=20 k=62 overwrite
rm temp.fq.gz; ln -s extended.fq.gz temp.fq.gz
## tadpole.sh，Uses kmer counts to assemble contigs, extend sequences, or error-correct reads.
## mode=extend，Extend sequences to be longer, and optionally perform error correction.
## extendleft=100，(el) Extend to the left by at most this many bases. 向左延伸最多的碱基数
## extendright=100，(er) Extend to the right by at most this many bases. 向右延伸最多的碱基数
## k=31，Kmer length (1 to infinity). Memory use increases with K. kmer的长度

log_info "Read merging"

## 合并序列
bbmerge-auto.sh \
    in=temp.fq.gz out=merged.raw.fq.gz outu=unmerged.raw.fq.gz \
    ihist=M.ihist.merge.txt \
    threads=12 -Xmx10g \
strict k=81 extend2=80 rem overwrite
## bbmerge-auto.sh，a wrapper for BBMerge that attempts to use all available memory, instead of a fixed amount
## ihist=<file>，(hist) Insert length histogram output file. 生成insert size的分布直方图
## strict=f，Decrease false positive rate and merging rate. 降低假阳性比例和合并比例
## k=31，Kmer length. 31 (or less) is fastest and uses the least memory, but higher values may be more accurate. kmer的长度
## extend2=0，Extend reads this much only after a failed merge attempt, or in rem/rsem mode. 
## rem=f，(requireextensionmatch) Do not merge if the predicted insert size differs before and after extension. 如果insert size延伸前后不一致则不合并

log_info "Dedupe merged reads"

# 去除重复的合并序列
clumpify.sh \
    in=merged.raw.fq.gz \
    out=M1.fq.gz \
    threads=12 -Xmx10g \
    dedupe dupesubs=0 \
    overwrite
## clumpify.sh，Sorts sequences to put similar reads near each other.
## dedupe=f，Remove duplicate reads. For pairs, both must match. By default, deduplication does not occur. 删除重复reads

log_info "Quality-trim the unmerged reads"

# 对未合并的reads进行质量修剪
bbduk.sh \
    in=unmerged.raw.fq.gz out=unmerged.trim.fq.gz \
    threads=12 -Xmx10g \
    qtrim=r trimq=15 minlen=60 overwrite

# Separates unmerged reads
## 分离未合并的reads
repair.sh \
    in=unmerged.trim.fq.gz \
    out=U1.fq.gz \
    out2=U2.fq.gz \
    outs=Us.fq.gz \
    threads=12 -Xmx10g \
    repair overwrite
## repair.sh，Re-pairs reads that became disordered or had some mates eliminated.
## repair=t，(rp) Fixes arbitrarily corrupted paired reads by using read names. 根据reads的名字，修复任意损伤的配对的reads

#----------------------------#
# Done.
#----------------------------#
log_info Done.

exit 0
