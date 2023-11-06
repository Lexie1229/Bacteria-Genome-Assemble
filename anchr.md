# [Anchr](https://github.com/wang-q/anchr)

* Anchr：the Assembler of N-free CHRomosomes.

### 目录

* [Install](#Install)
* [Synopsis](#Synopsis)
* [Runtime_Dependences](#Runtime_Dependences)
* [Individual_Subcommands](#Individual_Subcommands)
* [Example](#Example)

### [Install](#Install)

```bash
mkdir -p ${HOME}/bin

# 获取有关repo的信息，提取符合要求的下载链接，解压并拷贝到特定位置
curl -fsSL $(
    curl -fsSL https://api.github.com/repos/wang-q/anchr/releases/latest |
        jq -r '.assets[] | select(.name == "anchr-x86_64-unknown-linux-musl.tar.gz").browser_download_url'
    ) |
    tar xvz
cp target/x86_64-unknown-linux-musl/release/anchr ${HOME}/bin
rm -fr target

# 测试是否安装成功
anchr --help
```

* jq：a lightweight and flexible command-line JSON processor.
    * jq [options] [jq filter] [file]
    * -r/--raw-output：if the filter's result is a string then it will be written directly to standard output rather than being formatted as a JSON string with quotes.
    * .items[].name：array construction to collect all the results of a filter into an array(创建数组去收集所有符合过滤条件的结果).
    * select(boolean_expression)：produce its input unchanged if returns true for the input, and produces no output otherwise(判断布尔值，如果为真则输出结果).

* API请求和响应：
    * API：application programming interface，应用程序编程接口
    * JSON格式

### [Synopsis](#Synopsis)

* anchr [SUBCOMMAND]
    * dep：Dependencies.
        * anchr dep [OPTIONS] infile
        * install：install dependencies(安装依赖).
        * check：check dependencies(检查依赖).
    * ena：ENA scripts.
        * anchr ena [OPTIONS] infile
        * info：Grab information from ENA(从ENA获取信息).
        * prep：Create downloading scripts(创建下载脚本).
    * trim：Trim Illumina PE/SE fastq files.
        * anchr trim [FLAGS] [OPTIONS] infiles
        * -q/--qual qual：Quality threshold [default:25] (质量分数阈值).
        * -l/--len len：Filter reads less or equal to this length [default:60] (reads长度).
        * -o/--outfile outfile：Output filename [stdout] for screen[default:trim.sh].
        * -p/--parallel parallel：Number of threads[default:8].
    * merge：Merge Illumina PE reads with bbtools.
        * anchr merge [OPTIONS] infiles
        * --ecphase ecphase：Error-correct phases. Phase 2 can be skipped [default:1 2 3] (指定合并的阶段).
        * -o/--outfile outfile：Output filename [stdout] for screen[default:merge.sh].
        * -p/--parallel parallel：Number of threads[default:8].
    * quorum：Run quorum to discard bad reads.
        * anchr quorum [OPTIONS] infiles
        * -o/--outfile outfile：Output filename [stdout] for screen[default:quorum.sh].
    * unitigs：Create unitigs from trimmed/merged reads.
        * anchr unitigs [OPTIONS] infiles
        * --kmer kmer：K-mer size to be used [default: 31].
        * -p/--parallel parallel：Number of threads [default: 8].
        * -u/--unitigger unitigger：Which unitig constructor to use: bcalm, bifrost, superreads, or tadpole [default:superreads] (指定unitig算法).
        * -o/--outfile outfile：Output filename. [stdout] for screen [default: unitigs.sh].
    * template：Creates Bash scripts.
        * anchr template [FLAGS] [OPTIONS]
        * --genome genome：Your best guess of the haploid genome size [default:1000000] (预测的基因组大小).
        * -p/--parallel parallel：Number of threads [default:8].
        * --xmx xmx：Set Java memory usage(设置使用的内存).
        * --queue queue：Queue name of the LSF cluster.
        * --fastqc：Run FastQC.
        * --insertsize：Calc insert sizes.
        * --kat：Run KAT.
        * --fastk：Run FastK
        * --trim trim：Opts for trim [default: --dedupe].
        * --qual qual：Quality threshold [default: 25 30] (质量分数阈值).
        * --len len：Filter reads less or equal to this length [default: 60] (reads长度).
        * --filter filter：Adapter, artifact, or both [default: adapter] (去除测序接头/建库过程中产生的污染序列).
        * --quorum：Run quorum.
        * --merge：Run merge reads.
        * --ecphase ecphase：Error-correct phases. Phase 2 can be skipped [default: 1 2 3].
        * --bwa bwa：Map trimmed reads to the genome.
        * --gatk：Calling variants with GATK Mutect2.
        * --cov cov：Down sampling coverages [default: 40 80].
        * -u/--unitigger unitigger：Unitigger used: bcalm, bifrost, superreads, or tadpole [default: bcalm].
        * --statp statp：Parts of stats [default: 2].
        * --readl readl：Length of reads [default: 100].
        * --uscale uscale：The scale factor for upper, (median + k * MAD) * u [default: 2].
        * --lscale lscale：The scale factor for upper, (median - k * MAD) / l [default: 3].
        * --redo：Redo anchors when merging anchors.
        * --extend：Extend anchors with other contigs.
        * --busco：Run busco.
    * anchors：Select anchors (proper covered regions) from contigs.
        * anchr anchors [FLAGS] [OPTIONS] infiles
        * --keepedge：Keep edges of anchors.
        * --longest：Only keep the longest proper region.
        * --fill fill：Fill holes short than or equal to this [default:1].
        * --lscale lscale：The scale factor for lower, (median - k*MAD) / l [default:3].
        * --min min：Minimal length of anchors [default:1000].
        * --mincov mincov>：Minimal coverage of reads [default:5].
        * --mscale mscale：The scale factor for MAD, median +/-k * MAD [default:3].
        * --ratio ratio：Fill large holes (opt.fill * 10) when covered ratio larger than this [default:0.98].
        * --readl readl：Length of reads [default:100] (指定reads长度).
        * --uscale uscale：The scale factor for upper, (median + k * MAD) * u [default:2].
        * -o/--outfile outfile：Output filename. [stdout] for screen [default:anchors.sh].
        * -p/--parallel parallel：Number of threads [default: 8].
    * help：Prints this message or the help of the given subcommand(s).

* 补充：
    * FASTQ格式：label/sequence/+/Q scores(ASCⅡ)
    * PE(Paired-End)：双端测序
    * SE(Single-End)：单端测序
    * ENA(European Nucleotide Archive)：provide a comprehensive record of the world’s nucleotide sequencing information, covering raw sequencing data, sequence assembly information and functional annotation

### [Runtime_Dependences](#Runtime_Dependences)

```bash
brew install perl cpanminus
brew install r
brew install parallel wget pigz
brew install datamash miller prettier
## 必须引用parallel，使用"parallel --citation"命令查询具体引用内容

brew tap wang-q/tap
brew install wang-q/tap/tsv-utils wang-q/tap/intspan
## brew tap user/repo：Tap a formula repository.

# Myer's dazzler wrapper
cpanm --installdeps App::Dazz
cpanm -nq App::Dazz
cpanm --verbose App::Dazz
## --installdeps：Only install dependencies
## cpanm Test::More：install Test::More
## -n/--notest：Do not run unit tests
## -q/--quiet：Turns off the most output
## -v/--verbose：Turns on chatty output

anchr dep install | bash
anchr dep check | bash
## 安装并检查anchr的依赖项

# Optional：fastk
brew install --HEAD wang-q/tap/fastk
brew install --HEAD wang-q/tap/merquryfk
## --HEAD：If formula defines it, install the HEAD version, aka. main, trunk, unstable, master(安装最新开发版本，此版本不一定稳定)

parallel -j 1 -k --line-buffer '
    Rscript -e '\'' if (!requireNamespace("{}", quietly = FALSE)) { install.packages("{}", repos="https://mirrors.tuna.tsinghua.edu.cn/CRAN") } '\''
    ' ::: \
        argparse minpack.lm \
        ggplot2 scales viridis
## 检查是否安装R包：argparse、minpack.lm、ggplot2、scales、viridis

# Optional：quast
# assembly quality assessment
brew install --HEAD brewsci/bio/quast
quast --test
## AttributeError: module 'cgi' has no attribute 'escape'
## 报错解决参考：https://github.com/ablab/quast/issues/157
## 解决：/home/linuxbrew/.linuxbrew/Cellar/quast/5.0.2/quast_libs/site_packages/jsontemplate/jsontemplate.py文件中的`cgi.escape`替换为`html.escape`，`import cgi`替换为`import html`

# Optional: leading assemblers
brew install spades
spades.py --test
brew install brewsci/bio/megahit
brew install wang-q/tap/platanus
```

* 安装失败，需要重新安装的依赖项

```bash
# 安装gatk，Genome Analysis Toolkit (offer a wide variety of tools with a primary focus on variant discovery and genotyping)
cd ~/biosoft
wget https://github.com/broadinstitute/gatk/archive/refs/tags/4.4.0.0.tar.gz -O gatk-4.4.0.0.tar.gz
tar xvzf gatk-4.4.0.0.tar.gz
cd gatk-4.4.0.0
sudo vim ~/.bashrc
source ~/.bashrc

# 安装quorum，Quality Optimized Reads from the University of Maryland，is an error corrector for Illumina reads
sudo apt install quorum

# 安装App::Fasops和App::Dazz
sudo cpan install App::Fasops
sudo cpan install App::Daz
```

* `cpanminus`：a script to get, unpack, build and install modules from CPAN(管理Perl模块的工具).
* `pigz`：a parallel implementation of gzip for modern multi-processor, multi-core machines(parallel implementation of gzip，并行压缩工具).
* `datamash`：a command-line program which performs basic numeric, textual and statistical operations on input textual data files(处理分析文本数据的工具).
* `miller`：a command-line tool for querying, shaping, and reformatting data files in various formats including CSV, TSV, JSON, and JSON Lines(查询、格式化各种格式的数据文件的工具).
* `prettier`：an opinionated code formatter(格式化代码格式).
* `intspan`：`spanr`(operates chromosome IntSpan files)、`rgr`(operates ranges in .rg and .tsv files)、`linkr`(operates ranges on chromosomes and links of ranges)、`ovlpr`(operates overlaps between sequences)，(处理整数集的工具).
* `App::Dazz`：Daligner-based UniTig utils
* `fastk`：a k‑mer counter that is optimized for processing high quality DNA assembly data sets such as those produced with an Illumina instrument or a PacBio run in HiFi mode(统计k-mer的工具).
* `MerquryFK`：FastK based version of Merqury，Merqury is a collection of R, Java, and shell scripts for producing k-mer analysis plots of genomic sequence data and assemblies with meryl as its core k-mer counter infra-structure(统计k-mer的工具).
* `quast`：QUality ASsessment Tool，evaluates genome/metagenome assemblies by computing various metrics(基因组组装质量评估工具).
* `SPAdes`：St. Petersburg genome assembler，an assembly toolkit containing various assembly pipelines(基因组组装工具).
* `megahit`：an ultra-fast and memory-efficient NGS(Next-Generation Sequencing) assembler, optimized for metagenomes, but also works well on generic single genome assembly (small or mammalian size) and single-cell assembly(基因组组装工具).
* `platanus`：a novel de novo sequence assembler that can reconstruct genomic sequences of
highly heterozygous diploids from massively parallel shotgun sequencing data(基因组从头组装工具).
* `R包`：
    * `argparse`：Command Line Optional and Positional Argument Parser，A command line parser to be used with 'Rscript' to write "#!" shebang scripts that gracefully accept positional and optional arguments and automatically generate usage(命令行解析器).
    * `minpack.lm`：R Interface to the Levenberg-Marquardt Nonlinear Least-Squares Algorithm Found in MINPACK, Plus Support for Bounds(最小二乘法).
    * `ggplot2`：Create Elegant Data Visualisations Using the Grammar of Graphics(数据可视化).
    * `scales`：Scale Functions for Visualization，Graphical scales map data to aesthetics, and provide methods for automatically determining breaks and labels for axes and legends(轴和图例).
    * `viridis`：Data frame of the viridis palette(调色板).

### [Individual_Subcommands](#Individual_Subcommands)

* `Lambda`：数据

```bash
mkdir -p ~/biodata/bga/anchr_test
cd ~/biodata/bga/anchr_test

# 下载：测序数据
for F in R1.fq.gz R2.fq.gz; do
    1>&2 echo ${F}
    curl -fsSLO "https://raw.githubusercontent.com/wang-q/anchr/main/tests/Lambda/${F}"
done
```

* `trim`：修剪

```bash
mkdir -p trim
pushd trim

# 修剪：质量分数≥25(准确度>99.7%)，reads长度≥60
anchr trim \
    ../R1.fq.gz ../R2.fq.gz \
    -q 25 -l 60 \
    -o stdout |
    bash
popd
```

```txt
# 结果
clumpify.fq.gz        Q25L60    R.filter.stats.txt  Rs.fq.gz                 temp.fq.gz
filter.fq.gz          R1.fq.gz  R.khist.txt         R.trim.stats.txt         trim.fq.gz
illumina_adapters.fa  R2.fq.gz  R.peaks.txt         sequencing_artifacts.fa

# Q25L60
R1.fq.gz  R2.fq.gz  Rs.fq.gz
```

* `merge`：合并

```bash
mkdir -p merge
pushd merge

# 合并：纠错包含三个步骤，使用BBTools
anchr merge \
    ../trim/R1.fq.gz ../trim/R2.fq.gz ../trim/Rs.fq.gz \
    --ecphase "1 2 3" \
    --parallel 4 \
    -o stdout |
    bash
popd
## Rs.fq.gz文件，包含修剪过程中筛选的仅存在于某一个方向的测序文件的reads
```

```txt
# 结果
clumped.fq.gz  ecct.fq.gz      merged.raw.fq.gz    temp.fq.gz  unmerged.raw.fq.gz
eccc.fq.gz     extended.fq.gz  M.ihist.merge1.txt  U1.fq.gz    unmerged.trim.fq.gz
ecco.fq.gz     M1.fq.gz        M.ihist.merge.txt   U2.fq.gz    Us.fq.gz
```

* `quorum`：纠错

```bash
# 纠错
pushd trim
anchr quorum \
    R1.fq.gz R2.fq.gz \
    -o stdout |
    bash
popd

# 纠错：Q25L60
pushd trim/Q25L60
anchr quorum \
    R1.fq.gz R2.fq.gz Rs.fq.gz \
    -o stdout |
    bash
popd
```

```txt
# 结果
env.json  pe.cor.fa.gz  pe.discard.lst  quorum.err   
```

* `unitigs` - superreads

```bash
gzip -dcf trim/pe.cor.fa.gz > trim/pe.cor.fa

mkdir -p superreads
pushd superreads

# 组装
anchr unitigs \
    ../trim/pe.cor.fa ../trim/env.json \
    --kmer "31 41 51 61 71 81" \
    --parallel 4 \
    -o unitigs.sh
bash unitigs.sh
popd
```

```txt
# 结果
env.json  pe.cor.fa  unitigs.fasta  unitigs.sh
```

* `unitigs` - TADpole

```bash
mkdir -p tadpole
pushd tadpole

anchr unitigs \
    ../trim/pe.cor.fa ../trim/env.json \
    -u tadpole \
    --kmer "31 41 51 61 71 81" \
    --parallel 4 \
    -o unitigs.sh
bash unitigs.sh
popd
```

* `unitigs` - BCALM：使用De Bruijn graph(DBG)组装算法

```bash
mkdir -p bcalm
pushd bcalm

anchr unitigs \
    ../trim/pe.cor.fa ../trim/env.json \
    -u bcalm \
    --kmer "31 41 51 61 71 81" \
    --parallel 4 \
    -o unitigs.sh
bash unitigs.sh
popd
```

* `anchors`

```bash
mkdir -p bcalm/anchors
pushd bcalm/anchors

anchr anchors \
    ../unitigs.fasta \
    ../pe.cor.fa \
    --readl 150 \
    --keepedge \
    -p 4 \
    -o anchors.sh
bash anchors.sh
popd
```

### [Example](#Example)

* Assemble Genomes：[model organisms(E. coli)](https://github.com/wang-q/anchr/blob/main/results/model.md)、[FDA-ARGOS bacteria](https://github.com/wang-q/anchr/blob/main/results/fda_argos.md)、[Yeast](https://github.com/wang-q/anchr/blob/main/results/yeast.md)

#### E. coli str. K-12 substr. DH5alpha

* Reference Genome

```bash
# 下载参考数据：dh5alpha
mkdir -p ~/biodata/bga/anchr/ref
cd ~/biodata/bga/anchr/ref
rsync -avP ftp.ncbi.nlm.nih.gov::genomes/all/GCF/001/723/505/GCF_001723505.1_ASM172350v1/ dh5alpha/

# 参考基因组
mkdir -p ~/biodata/bga/anchr/dh5alpha/1_genome
cd ~/biodata/bga/anchr/dh5alpha/1_genome
## genome
find ~/biodata/bga/anchr/ref/dh5alpha/ -name "*_genomic.fna.gz" |
    grep -v "_from_" |
    xargs gzip -dcf |
    faops filter -N -s stdin genome.fa
## -N：convert IUPAC ambiguous codes to 'N'
## -s：simplify sequence names
```

* Sequencing Data Download

```bash
mkdir -p ~/biodata/bga/anchr/dh5alpha/2_illumina
cd ~/biodata/bga/anchr/dh5alpha/2_illumina

# 下载测序数据：ena
aria2c -x 9 -s 3 -c ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR112/039/SRR11245239/SRR11245239_1.fastq.gz
aria2c -x 9 -s 3 -c ftp://ftp.sra.ebi.ac.uk/vol1/fastq/SRR112/039/SRR11245239/SRR11245239_2.fastq.gz

# 建立软链接，以确保测序数据文件名的格式
ln -s SRR11245239_1.fastq.gz R1.fq.gz
ln -s SRR11245239_2.fastq.gz R2.fq.gz

## 以下部分存在问题
mkdir -p ~/biodata/bga/anchr/dh5alpha/ena
cd ~/biodata/bga/anchr/dh5alpha/ena

# 将dh5alpha相关测序信息写入source.csv文件
cat << EOF > source.csv
SRP251726,dh5alpha,HiSeq 2500 PE125
EOF
## accession_id/strain_name/sequencing_system
## PE125：Paired-end 125bp sequencing

# 从ENA获取相关信息，并创建下载脚本
anchr ena info | perl - -v source.csv > ena_info.yml
anchr ena prep | perl - ena_info.yml
## 生成文件：ena_info.csv、ena_info.ftp.txt、ena_info.md5.txt

# 查看ena_info.csv文件，即ENA中符合搜索条件的条目
mlr --icsv --omd cat ena_info.csv
## --icsv：输入csv文件
## --omd：输出md文件
## cat：input records directly to output

# 下载测序数据
aria2c -x 9 -s 3 -c -i ena_info.ftp.txt
## -x/--max-connection-per-server=NUM：The maximum number of connections to one server for each download
## -s/--split=N：Download a file using N connections
## -c/--continue[=true|false]：Continue downloading a partially downloaded file
## -i/--input-file=FILE：Downloads URIs found in FILE
## -j/--max-concurrent-downloads=N：Set maximum number of parallel downloads for every static (HTTP/FTP) URL, torrent and metalink
## --file-allocation=METHOD：Specify file allocation method, 'none' doesn't pre-allocate file space

# 检查文件是否正确传输
md5sum --check ena_info.md5.txt
## -c/--check：read checksums from the FILEs and check them
## md5sum：compute and check MD5 message digest
## MD5 checksum：a 32-character hexadecimal number that is computed on a file

# Illumina
mkdir -p ~/biodata/bga/anchr/dh5alpha/2_illumina
cd ~/biodata/bga/anchr/dh5alpha/2_illumina

# 建立软链接，以确保测序数据文件名的格式
ln -s ../ena/SRR11245239_1.fastq.gz R1.fq.gz
ln -s ../ena/SRR11245239_2.fastq.gz R2.fq.gz
```

* 补充：取样

```bash
# sampling reads as test materials
mkdir -p ~/biodata/bga/anchr/dh5alpha/2_sample
cd ~/biodata/bga/anchr/dh5alpha/2_sample

# 抽样：随机种子、样本数
seqtk sample -s 23 ../ena/SRR11245239_1.fastq.gz 20000 | pigz > R1.fq.gz
seqtk sample -s 23 ../ena/SRR11245239_2.fastq.gz  20000 | pigz > R2.fq.gz
## seqtk：processe sequences in the FASTA or FASTQ format
## seqtk sample [-2] [-s seed=11] <in.fa> <frac>|<number>
```

* Generate Template

```bash
WORKING_DIR=${HOME}/biodata/bga/anchr
BASE_NAME=dh5alpha

cd ${WORKING_DIR}/${BASE_NAME}

# 创建脚本：Info/Quality_check/trimming/post_trimming/(Mapping)/down_sampling,unitigs,anchors/extend_anchors
rm *.sh
anchr template \
    --genome 4583637 \
    --parallel 12 \
    --xmx 10g \
    --queue mpi \
    # Info
    \ 
    --fastqc \
    --insertsize \
    --kat \
    # Quality check：2_fastqc.sh、2_insert_size.sh、2_kat.sh
    \
    --trim "--dedupe --cutoff 30 --cutk 31" \
    --qual "25 30" \
    --len "60" \
    --filter "adapter artifact" \
    # trimming：2_trim.sh--9_stat_reads.sh
    \
    --quorum \
    --merge \
    --ecphase "1 2 3" \
    # Post-trimming：2_merge.sh、2_quorum.sh
    \
    --cov "40 80" \
    --unitigger "superreads bcalm tadpole" \
    --statp 2 \
    --readl 125 \
    --uscale 2 \
    --lscale 3 \
    --redo \
    # Down sampling, unitigs, and anchors
    \
    --extend \
    \
    --busco
## 调整并行个数parallel和内存大小xmx
```

```text
# 生成的脚本文件
Create 2_fastqc.sh
Create 2_insert_size.sh
Create 2_kat.sh
Create 2_trim.sh
Create 9_stat_reads.sh
Create 2_quorum.sh
Create 4_down_sampling.sh
Create 4_unitigs_superreads.sh
Create 4_unitigs_bcalm.sh
Create 4_unitigs_tadpole.sh
Create 4_anchors.sh
Create 9_stat_anchors.sh
Create 2_merge.sh
Create 6_down_sampling.sh
Create 6_unitigs_superreads.sh
Create 6_unitigs_bcalm.sh
Create 6_unitigs_tadpole.sh
Create 6_anchors.sh
Create 9_stat_mr_anchors.sh
Create 7_merge_anchors.sh
Create 9_stat_merge_anchors.sh
Create 8_spades.sh
Create 8_megahit.sh
Create 8_platanus.sh
Create 8_mr_spades.sh
Create 8_mr_megahit.sh
Create 9_stat_other_anchors.sh
Create 7_glue_anchors.sh
Create 7_fill_anchors.sh
Create 9_quast.sh
Create 9_stat_final.sh
Create 9_busco.sh
Create 0_cleanup.sh
Create 0_real_clean.sh
Create 0_master.sh
Create 0_bsub.sh
```

* Genome Assemble

```bash
WORKING_DIR=${HOME}/biodata/bga/anchr
BASE_NAME=dh5alpha

cd ${WORKING_DIR}/${BASE_NAME}
# rm -fr 4_*/ 6_*/ 7_*/ 8_*/
# rm -fr 2_illumina/trim 2_illumina/merge statReads.md
# rm -fr 4_down_sampling 6_down_sampling

# BASE_NAME=dh5alpha bash 0_bsub.sh
bsub -q mpi -n 24 -J "${BASE_NAME}-0_master" "bash 0_master.sh"
# bkill -J "${BASE_NAME}-*"

# bash 0_master.sh
# bash 0_cleanup.sh
```

```bash
cd ${WORKING_DIR}/${BASE_NAME}
# rm -fr 4_*/ 6_*/ 7_*/ 8_*/
# rm -fr 2_illumina/trim 2_illumina/merge statReads.md
# rm -fr 4_down_sampling 6_down_sampling

# BASE_NAME=mg1655 bash 0_bsub.sh
bsub -q mpi -n 24 -J "${BASE_NAME}-0_master" "bash 0_master.sh"
# bkill -J "${BASE_NAME}-*"

# bash 0_master.sh
# bash 0_cleanup.sh

cd ${WORKING_DIR}/${BASE_NAME}
# rm -fr 4_*/ 6_*/ 7_*/ 8_*/
# rm -fr 2_illumina/trim 2_illumina/merge statReads.md
# rm -fr 4_down_sampling 6_down_sampling

bash 0_master.sh

prettier -w 9_markdown/*.md

# bash 0_cleanup.sh
```

#### E. coli str. K-12 substr. MG1655

* Reference Genome

```bash
# 下载参考数据：mg1655
mkdir -p ~/biodata/bga/anchr/ref
cd ~/biodata/bga/anchr/ref
rsync -avP ftp.ncbi.nlm.nih.gov::genomes/all/GCF/000/005/845/GCF_000005845.2_ASM584v2/ mg1655/

# 参考基因组
mkdir -p ~/biodata/bga/anchr/mg1655/1_genome
cd ~/biodata/bga/anchr/mg1655/1_genome
## genome
find ~/biodata/bga/anchr/ref/mg1655/ -name "*_genomic.fna.gz" |
    grep -v "_from_" |
    xargs gzip -dcf |
    faops filter -N -s stdin genome.fa
## -N：convert IUPAC ambiguous codes to 'N'
## -s：simplify sequence names
```

* Sequencing Data Download

```bash
mkdir -p ~/biodata/bga/anchr/mg1655/2_illumina
cd ~/biodata/bga/anchr/mg1655/2_illumina

# 下载测序数据：illumina
aria2c -x 9 -s 3 -c ftp://webdata:webdata@ussd-ftp.illumina.com/Data/SequencingRuns/MG1655/MiSeq_Ecoli_MG1655_110721_PF_R1.fastq.gz
aria2c -x 9 -s 3 -c ftp://webdata:webdata@ussd-ftp.illumina.com/Data/SequencingRuns/MG1655/MiSeq_Ecoli_MG1655_110721_PF_R2.fastq.gz

# 建立软链接，以确保测序数据文件名的格式
ln -s MiSeq_Ecoli_MG1655_110721_PF_R1.fastq.gz R1.fq.gz
ln -s MiSeq_Ecoli_MG1655_110721_PF_R2.fastq.gz R2.fq.gz
```

* Generate Template

```bash
WORKING_DIR=${HOME}/biodata/bga/anchr
BASE_NAME=mg1655

cd ${WORKING_DIR}/${BASE_NAME}

# 生成脚本
rm *.sh
anchr template \
    --genome 4641652 \
    --parallel 24 \
    --xmx 80g \
    --queue mpi \
    \
    --fastqc \
    --insertsize \
    --kat \
    \
    --trim "--dedupe --tile --cutoff 30 --cutk 31" \
    --qual "25 30" \
    --len "60" \
    --filter "adapter artifact" \
    \
    --quorum \
    --merge \
    --ecphase "1 2 3" \
    \
    --bwa "Q25L60" \
    --gatk \
    \
    --cov "40 80" \
    --unitigger "superreads bcalm tadpole" \
    --statp 2 \
    --readl 151 \
    --uscale 2 \
    --lscale 3 \
    --redo \
    \
    --extend \
    \
    --busco
## 超算组装
```

#### Mycoplasma genitalium G37

* Reference Genome

```bash
# 下载参考数据：g37
mkdir -p ~/biodata/bga/anchr/ref
cd ~/biodata/bga/anchr/ref
rsync -avP ftp.ncbi.nlm.nih.gov::genomes/all/GCF/000/027/325/GCF_000027325.1_ASM2732v1/ g37/

# 参考基因组
mkdir -p ~/biodata/bga/anchr/g37/1_genome
cd ~/biodata/bga/anchr/g37/1_genome
## genome
find ~/biodata/bga/anchr/ref/g37/ -name "*_genomic.fna.gz" |
    grep -v "_from_" |
    xargs gzip -dcf |
    faops filter -N -s stdin genome.fa
## -N：convert IUPAC ambiguous codes to 'N'
## -s：simplify sequence names
```

* Sequencing Data Download

```bash
mkdir -p ~/biodata/bga/anchr/g37/2_illumina
cd ~/biodata/bga/anchr/g37/2_illumina

# 下载测序数据：ena
aria2c -x 9 -s 3 -c ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR486/ERR486835/ERR486835_1.fastq.gz
aria2c -x 9 -s 3 -c ftp://ftp.sra.ebi.ac.uk/vol1/fastq/ERR486/ERR486835/ERR486835_2.fastq.gz

# 建立软链接，以确保测序数据文件名的格式
ln -s ERR486835_1.fastq.gz R1.fq.gz
ln -s ERR486835_2.fastq.gz R2.fq.gz
```

* Generate Template

```bash
WORKING_DIR=${HOME}/biodata/bga/anchr
BASE_NAME=g37

cd ${WORKING_DIR}/${BASE_NAME}

# 生成脚本
rm *.sh
anchr template \
    --genome 580076 \
    --parallel 10 \
    --xmx 10g \
    \
    --fastqc \
    --insertsize \
    --fastk \
    \
    --trim "--dedupe --cutoff 30 --cutk 31" \
    --qual "25 30" \
    --len "60" \
    --filter "adapter artifact" \
    \
    --quorum \
    --merge \
    --ecphase "1 2 3" \
    \
    --cov "40 80" \
    --unitigger "bcalm bifrost superreads tadpole" \
    --statp 2 \
    --readl 125 \
    --uscale 2 \
    --lscale 3 \
    --redo \
    \
    --extend
# 本地组装
# --parallel和--xmx根据本地实际核数和内存大小调整
```

* Genome Assemble

```bash
WORKING_DIR=${HOME}/biodata/bga/anchr
BASE_NAME=g37

cd ${WORKING_DIR}/${BASE_NAME}

bash 0_master.sh
# 脚本执行顺序
# 2_fastqc.sh|2_insert_size.sh
# 2_trim.sh|9_stat_reads.sh
# 2_merge.sh|2_quorum.sh
# 4_down_sampling.sh
# 4_unitigs_bcalm.sh|4_anchors.sh|9_stat_anchors.sh
# 4_unitigs_bifrost.sh|4_anchors.sh|9_stat_anchors.sh|
# 4_unitigs_superreads.sh|4_anchors.sh|9_stat_anchors.sh
# 4_unitigs_tadpole.sh|4_anchors.sh|9_stat_anchors.sh
# 6_down_sampling.sh
# 6_unitigs_bcalm.sh|6_anchors.sh|9_stat_anchors.sh
# 6_unitigs_bifrost.sh|6_anchors.sh|9_stat_anchors.sh
# 6_unitigs_superreads.sh|6_anchors.sh|9_stat_anchors.sh
# 6_unitigs_tadpole.sh|6_anchors.sh|9_stat_anchors.sh
# 7_merge_anchors.sh|9_stat_merge_anchors.sh

# 存在问题bifrost

prettier -w 9_markdown/*.md

bash 0_cleanup.sh
```