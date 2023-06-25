# [Anchr](https://github.com/wang-q/anchr)

* Anchr：the Assembler of N-free CHRomosomes.

### Install

```bash
mkdir -p ${HOME}/bin

# 获取有关repo的信息，提取符合要求的下载链接，解压并拷贝到特定位置
mkdir -p ${HOME}/bin
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
    * jq [options] jq filter [file]
    * -r/--raw-output：if the filter's result is a string then it will be written directly to standard output rather than being formatted as a JSON string with quotes.
    * .items[].name：array construction to collect all the results of a filter into an array(创建数组去收集所有符合过滤条件的结果).
    * select(boolean_expression)：produce its input unchanged if returns true for the input, and produces no output otherwise(判断布尔值，如果为真则输出结果).

* API请求和响应：
    * API：application programming interface，应用程序编程接口
    * JSON格式

### Dependences

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

## 安装App::Fasops和App::Dazz
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

### Dependences

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

## 安装App::Fasops和App::Dazz
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

### Subcommands

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
