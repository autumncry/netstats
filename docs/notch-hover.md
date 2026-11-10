# 玻璃功能卡片 / Glass hub

菜单栏与屏顶入口共用同一套六功能卡片。点击齿轮打开独立设置窗口，分别启用网络、设备、日历、天气、剪切板、暂存架。初始启用网络、设备、暂存架；其他功能需要主动启用和配置。关闭当前功能后切到首个可用项，全关时显示设置引导。

下述自动顶栏、双指切页、登录自启和关于页属于 v2.02（2.0.2）待发布更新；现有 v2.01 下载包不包含这些改动。详见 [v2.02 更新说明](release-notes/v2.02.md)。

## 使用

- 在通用设置启用屏顶卡片，连续悬停1秒展开；移出入口和卡片300毫秒收起。入口默认关闭，并保留已有用户的开关选择。
- 显示模式默认自动：优先使用可用的内置实体刘海，没有刘海屏时在主显示器菜单栏下方显示顶栏。也可手动选择刘海或顶栏；显式选择刘海但没有对应屏幕时提示不可用。顶栏可以点击展开，关闭暂存架也不会移除顶栏入口。
- 底部 Dock 点击切换功能，普通打开默认进入网络或首个启用项。齿轮始终可用并打开独立设置窗口；菜单栏再次点击仍关闭面板。
- 卡片内用触控板双指左右滑动切页，每个手势最多一页，跳过关闭的功能，两端不循环；惯性不会继续翻页。纵向滑动仍浏览列表，输入、弹窗和拖放期间不切页。
- 用户切页采用约240毫秒的有方向滑动与淡入淡出，底部功能栏不参与横向位移，不同页高度平滑衔接。系统开启“减少动态效果”后改用约120毫秒淡入淡出。首次展开及文件拖入不播放翻页动画。
- 搜索编辑、子弹窗、文件拖放期间保持展开。点击外部结束交互；面板内 Esc 优先关闭子弹窗，再关闭卡片。被动浏览和 Dock 点击不抢焦点，主动点击输入区域才取得键盘焦点。
- 将有效文件/文件夹拖到实体刘海500毫秒展开暂存架，松手才添加引用。拖出采用复制语义，移除引用不影响原件。
- 「详情」进入原 Native / Terminal 完整监控，Clash 信息和旧显示选项继续可用；两个入口互斥显示。
- 睡眠、屏幕、会话或 Space 变化时关闭，恢复后重新进入才触发。

## 内容与保存

卡片宽360pt，网络/天气208pt，暂存架232pt，设备/日历/剪切板248pt；设备页给四组指标和磁盘I/O留出完整空间及底部间距。设置使用独立的可调整大小窗口，初始内容尺寸为780×620pt。macOS26+ 使用系统玻璃，旧版使用原生模糊材质，并响应减少透明度/动态效果。不是使用设计PNG作为产品背景。

网络的下载、上传使用上下两行，数值和单位同列对齐；蓝色下载、橙色上传分别对应同一量程的趋势。卡片仅保留实时速率及“启动后累计”，接口标识留在详情中。设备显示CPU、GPU型号/可用负载、内存及启动盘容量；磁盘I/O为全部块设备合计。不可用GPU读数显示“—”，不会伪装成0%。

日历设置显式请求系统 Full Access，首版只查询日程；创建和编辑打开系统 Calendar。天气需要[配置系统快捷指令](weather-shortcut.md)，验证成功后15分钟缓存、20秒CLI超时，失败保留上次数据。

剪切板支持文字/图片、本机持久化、搜索分页、预览与复制回剪切板。默认保留30天，文字/图片分别支持数量不限或自定义上限；保存期限可设1–30天。暂停不会补录暂停期间内容，关闭功能仍清理过期历史。新版macOS在允许后台读取前暂停，不通过悬停请求权限。暂存架保存书签引用，支持重启、失效重连与离线提示。

详见 [Privacy](PRIVACY.md) 和 [Permissions](PERMISSIONS.md)。

## 独立设置

菜单栏、屏顶卡片和完整监控的齿轮都打开同一个设置窗口。左侧分类包含通用、功能、显示与监控、日历、天气、剪切板、暂存架和关于；菜单栏指标、悬停提示、详情样式及各功能配置集中在这里。窗口有标准关闭按钮并可调整大小，移开鼠标或切换应用不会自动收起。设置窗口保持打开时也能使用悬停；打开设置只收起当时的卡片，鼠标移出入口后重新进入即可再次触发。

通用页的“登录时启动”使用系统 SMAppService，读取真实注册/批准状态，不会默认启用。需要批准或发生错误时显示原因及系统设置入口。关于页展示 Bundle 版本与构建号、版权、MIT 协议和 GitHub 链接；Star 按钮只打开项目页，不会替用户执行 Star。

## 本地运行

```sh
swift test
swift run NetStatsLogicTests
NETSTATS_BUILD_CONFIGURATION=release ./script/build_and_run.sh --verify
```

Codex Run动作使用同一脚本。开发bundle仅作本机临时签名，未做发行公证。菜单栏/刘海均可直接进入共享设置。

## English

Both entrances use one360pt adaptive glass card, shared feature switches and services. The Dock switches Network, Device, Calendar, Weather, Clipboard and Shelf by click. Network, Device and Shelf start enabled. The optional physical-notch entrance uses1-second hover,300ms exit grace and500ms valid-file drag dwell. Editing, owned popovers and dragging keep the card open. Passive navigation never activates the app; explicit text input can make the panel key but never main.

The pending v2.02 (2.0.2) update adds horizontal two-finger paging, Automatic/Notch/Top bar modes, system-backed launch at login, and About. Automatic uses the built-in physical notch when available and otherwise places a clickable strip below the primary screen's menu bar. Paging skips disabled features, stops at the ends, and preserves vertical scrolling and editing. These changes are not in the v2.01 download. See the [v2.02 notes](release-notes/v2.02.md).

User page changes slide and fade over about 240 ms with coordinated panel resizing; the navigation bar does not slide sideways. Reduce Motion uses a short fade instead. Opening the card and file-drop selection are immediate, and departing pages cannot affect the newly active page's interaction state.

Download and Upload are stacked with aligned value/unit columns and paired, shared-scale trends. Interface identifiers stay in Details. Dock icons and labels have fixed aligned slots. Every gear opens one independent, resizable Settings window; moving the pointer away or switching apps does not dismiss it. General, Features, Display & Monitoring, Calendar, Weather, Clipboard and Shelf contain all preferences.

Calendar requests Full Access explicitly but only queries events. Weather requires a configured and verified system shortcut, caches for15minutes and times out the CLI after20seconds. Clipboard text/images persist locally with1–30day retention and separate unlimited-by-default counts. Pause/disable/clear cancel pending captures. Shelf stores bookmarks, never deletes source files, and drags out with copy semantics. Existing Native/Terminal monitoring and Clash remain available through Details.

## 验证边界 / Validation

自动测试覆盖计时、屏幕几何、设置/选择、权限策略、存储/分页/清理、文件引用、天气解析/缓存与真实测试子进程超时，以及各布局的离屏渲染。离屏图片不代表真实桌面上的玻璃效果；日历/剪切板首次授权、真实天气快捷指令、实体刘海拖放、前台输入、全屏/外接屏及睡眠唤醒仍需在运行App中真机验收。

设计参考 Boring Notch、Atoll 和 DynamicNotchKit 的交互思路，独立实现，无新增第三方依赖。

布局参考：[Stats 网络面板](https://github.com/exelban/stats/blob/master/Modules/Net/popup.swift)的方向颜色与趋势对应关系，以及 [iStat Menus](https://bjango.com/mac/istatmenus/)的概览与连接详情分层。上下两行是针对本卡片与用户反馈作出的布局选择。
