

# iOS14 归因DEMO

本DEMO由两部分组成。一是演示iOS14跟踪权限流程；二是演示如何定义SKAdNetwork转化值。

## iOS14跟踪权限流程

iOS14新增了跟踪权限弹框，由于该弹框只出现一次，为了在用户选择不同意进行权限跟踪后还有机会展示跟踪权限弹框，可以在正式弹窗前进行预弹窗。在预弹窗里，若用户选择“同意”，再进行正式弹框；若用户选择“不同意”，则不展示正式弹框。与此同时，还演示了在跟踪权限不同状态时调用系统归因API获取归因数据及IDFA值。

## SKAdNetwork转化值

SKAdNetwork有两个API，一个是registerAppForAdNetworkAttribution；一个是updateConversionValue。registerAppForAdNetworkAttribution调用非常简单，只需在程序入口处执行代码`[SKAdNetwork registerAppForAdNetworkAttribution]`即可；而updateConversionValue稍复杂些，它接收一个参数，该参数表示最新转化值，是一个6比特位的无符号数，取值范围为0-63，本DEMO主要演示如何定义该转化值。

我们将该6比特位分割成两部分：高3位和低3位。高3位表示购买事件；低3位表示关卡事件。购买事件及关卡事件对照表如下：

购买事件

| 二进制 | 购买事件       |
| -----: | -------------- |
|    000 | -              |
|    001 | purchase > $1  |
|    010 | purchase > $2  |
|    011 | purchase > $3  |
|    100 | purchase > $5  |
|    101 | purchase > $10 |
|    110 | purchase > $15 |
|    111 | purchase > $20 |

关卡事件

| 二进制 | 关卡事件            |
| -----: | ------------------- |
|    000 | -                   |
|    001 | 1 level completed   |
|    010 | 5 level completed   |
|    011 | 10 level completed  |
|    100 | 15 level completed  |
|    101 | 20 level completed  |
|    110 | 25 level completed  |
|    111 | 30+ level completed |

高3位与低3位根据以上对照表组合出不同的事件，如35（100011）表示10 level completed并且purchase > $5。实际中事件的定义需结合具体的业务及应用场景进行定义，本DEMO仅供参考。

注：文件`LJHConversion.h`和`LJHConversion.m`参考了项目https://github.com/2ndpotion/ElixiriOS ，原始项目是用swift编写的，本DEMO参考其设计用objective-c进行实现。



