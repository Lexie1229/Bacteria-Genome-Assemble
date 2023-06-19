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