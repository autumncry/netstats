# 发布 NetStats 应用内更新

从首个带 Sparkle 的版本起，用户可以在 **设置 → 关于 → 检查更新** 查看新版并下载。自动检查默认关闭。用户也可以开启“自动检查更新”，再选择“自动下载更新，并在退出时安装”。两个选项由 Sparkle 存入用户偏好，并跨应用重启生效。只开启自动检查时，新版本由用户确认安装。

首次升级到支持应用内更新的版本需手动下载安装。应用从 GitHub 的固定 HTTPS 地址读取签名清单。当前仓库的初始清单是已签名的空频道。首个可供更新的安装包发布后，维护者再替换清单。

## 密钥

NetStats 的 Sparkle EdDSA 私钥保存在发布者 Mac 的钥匙串，账户名为 `NetStats`。应用的 `Resources/Info.plist` 内只嵌入公钥，要求签名清单并在解压前验证下载包。发布者应按 [Sparkle 官方密钥说明](https://sparkle-project.org/documentation/#3-generate-an-eddsa-key) 安全备份、迁移同一密钥。私钥不得放进仓库、构建日志或发行附件。其他开发者构建及验证签名不需要发布者私钥。

## 生成候选更新

1. 递增 `CFBundleVersion`，核对应用版本、`npm/package.json` 的 `version` 和 `githubReleaseTag`、以及对应的发布说明。构建号须大于上一正式更新。
2. 构建通用包及候选签名清单。若已有本机开发包正在使用，可以设置 `NETSTATS_BUILD_DIR` 和 `NETSTATS_DIST_DIR` 指向新的输出目录，两条命令保持同一组环境变量。

   ```sh
   NETSTATS_UNIVERSAL=1 scripts/package_dmg.sh release
   scripts/make_appcast.sh
   ```

   默认产物为 `dist/NetStats-<应用版本>.dmg`、同名 SHA-256 文件及 `dist/appcast.xml`。签名工具会通过钥匙串读取 NetStats 密钥；完成签名后会用应用内公钥校验清单、镜像、下载链接、系统和应用版本。发行包重建后请重新签名。
3. 发布正式 Git 标签、DMG 和 SHA-256 附件。核验从正式 GitHub Release 下载的 DMG 与候选文件一致，再将 **已验证的** `dist/appcast.xml` 原样提交至默认分支 `updates/appcast.xml`。已有用户读取这个固定清单：

   [正式更新清单](https://raw.githubusercontent.com/autumncry/netstats/main/updates/appcast.xml)

4. 以旧构建在“关于”页检查更新，核对版本说明、确认下载和重启后的版本。已经公开的更新附件请保留原始字节。

要独立验证已发布的清单及下载包，使用 `swift scripts/verify_appcast.swift Resources/Info.plist appcast.xml vTAG NetStats-VERSION.dmg`。仅验证初始空频道时，省略最后两个参数。关于上游行为可参阅 [Sparkle 更新发布文档](https://sparkle-project.org/documentation/publishing/) 和 [自动更新配置](https://sparkle-project.org/documentation/customization/)。
