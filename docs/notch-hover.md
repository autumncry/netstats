# 玻璃功能卡片 / Glass hub

菜单栏点击与内置实体刘海悬停共用同一套六功能卡片。点击齿轮打开独立设置窗口，分别启用网络、设备、日历、天气、剪切板、暂存架。初始启用网络、设备、暂存架；其他功能需要主动启用和配置。关闭当前功能后切到首个可用项，全关时显示设置引导。

## 使用

- 在共享设置打开刘海入口，连续悬停1秒展开；移出刘海和卡片300毫秒收起。刘海入口默认关闭，无可用内置刘海屏时保留设置。
- 底部 Dock 点击切换功能，普通打开默认进入网络或首个启用项。齿轮始终可用并打开独立设置窗口；菜单栏再次点击仍关闭面板。
- 搜索编辑、子弹窗、文件拖放期间保持展开。点击外部结束交互；面板内 Esc 优先关闭子弹窗，再关闭卡片。被动浏览和 Dock 点击不抢焦点，主动点击输入区域才取得键盘焦点。
- 将有效文件/文件夹拖到实体刘海500毫秒展开暂存架，松手才添加引用。拖出采用复制语义，移除引用不影响原件。
- 「详情」进入原 Native / Terminal 完整监控，Clash 信息和旧显示选项继续可用；两个入口互斥显示。
- 睡眠、屏幕、会话或 Space 变化时关闭，恢复后重新进入才触发。

## 内容与保存

卡片宽360pt，网络/天气208pt，设备/暂存架232pt，日历/剪切板248pt；设置使用独立的可调整大小窗口，初始内容尺寸为780×620pt。macOS26+ 使用系统玻璃，旧版使用原生模糊材质，并响应减少透明度/动态效果。不是使用设计PNG作为产品背景。

网络的下载、上传使用上下两行，数值和单位同列对齐；蓝色下载、橙色上传分别对应同一量程的趋势。卡片仅保留实时速率及“启动后累计”，接口标识留在详情中。设备显示CPU、GPU型号/可用负载、内存及启动盘容量；磁盘I/O为全部块设备合计。不可用GPU读数显示“—”，不会伪装成0%。

日历设置显式请求系统 Full Access，首版只查询日程；创建和编辑打开系统 Calendar。天气需要[配置系统快捷指令](weather-shortcut.md)，验证成功后15分钟缓存、20秒CLI超时，失败保留上次数据。

剪切板支持文字/图片、本机持久化、搜索分页、预览与复制回剪切板。默认保留30天，文字/图片分别支持数量不限或自定义上限；保存期限可设1–30天。暂停不会补录暂停期间内容，关闭功能仍清理过期历史。新版macOS在允许后台读取前暂停，不通过悬停请求权限。暂存架保存书签引用，支持重启、失效重连与离线提示。

详见 [Privacy](PRIVACY.md) 和 [Permissions](PERMISSIONS.md)。

## 独立设置

菜单栏、刘海卡片和完整监控的齿轮都打开同一个设置窗口。左侧分类包含通用、功能、显示与监控、日历、天气、剪切板和暂存架；菜单栏指标、悬停提示、详情样式及各功能配置集中在这里。窗口有标准关闭按钮并可调整大小，移开鼠标或切换应用不会自动收起。设置窗口保持打开时也能使用刘海悬停；打开设置只收起当时的卡片，鼠标移出刘海后重新进入即可再次触发。

## 本地运行

```sh
swift test
swift run NetStatsLogicTests
NETSTATS_BUILD_CONFIGURATION=release ./script/build_and_run.sh --verify
```

Codex Run动作使用同一脚本。开发bundle仅作本机临时签名，未做发行公证。菜单栏/刘海均可直接进入共享设置。

## English

Both entrances use one360pt adaptive glass card, shared feature switches and services. The Dock switches Network, Device, Calendar, Weather, Clipboard and Shelf by click. Network, Device and Shelf start enabled. The optional physical-notch entrance uses1-second hover,300ms exit grace and500ms valid-file drag dwell. Editing, owned popovers and dragging keep the card open. Passive navigation never activates the app; explicit text input can make the panel key but never main.

Download and Upload are stacked with aligned value/unit columns and paired, shared-scale trends. Interface identifiers stay in Details. Dock icons and labels have fixed aligned slots. Every gear opens one independent, resizable Settings window; moving the pointer away or switching apps does not dismiss it. General, Features, Display & Monitoring, Calendar, Weather, Clipboard and Shelf contain all preferences.

Calendar requests Full Access explicitly but only queries events. Weather requires a configured and verified system shortcut, caches for15minutes and times out the CLI after20seconds. Clipboard text/images persist locally with1–30day retention and separate unlimited-by-default counts. Pause/disable/clear cancel pending captures. Shelf stores bookmarks, never deletes source files, and drags out with copy semantics. Existing Native/Terminal monitoring and Clash remain available through Details.

## 验证边界 / Validation

自动测试覆盖计时、屏幕几何、设置/选择、权限策略、存储/分页/清理、文件引用、天气解析/缓存与真实测试子进程超时，以及各布局的离屏渲染。离屏图片不代表真实桌面上的玻璃效果；日历/剪切板首次授权、真实天气快捷指令、实体刘海拖放、前台输入、全屏/外接屏及睡眠唤醒仍需在运行App中真机验收。

设计参考 Boring Notch、Atoll 和 DynamicNotchKit 的交互思路，独立实现，无新增第三方依赖。

布局参考：[Stats 网络面板](https://github.com/exelban/stats/blob/master/Modules/Net/popup.swift)的方向颜色与趋势对应关系，以及 [iStat Menus](https://bjango.com/mac/istatmenus/)的概览与连接详情分层。上下两行是针对本卡片与用户反馈作出的布局选择。
