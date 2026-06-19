# StarryNote ✨

StarryNote 是为 [Starry Blog](../Starry-Blog) 定制的本地 Flutter 写作与管理工具。它直接操作博客 Git 工作区，不引入额外服务端。

## 已实现

- 通过 Git URL 克隆或连接已有 Starry Blog 工作区；私有 HTTPS 仓库支持用户名 + PAT。
- Markdown 文章列表、创建、编辑、删除与实时预览。
- 按标题、日期、分类、作者、封面、摘要和标签生成标准 YAML frontmatter。
- 保存文章时重建 `public/articles/index.json`，随后自动创建 Git commit；Push 必须手动触发。
- 一键撤销最后一次本地提交（文件改动保留，方便继续修改）。
- 粘贴图片时使用 AWS Signature V4 直传 Cloudflare R2，并在光标处插入公开 URL。
- 通过 Supabase PostgREST 浏览和删除评论。
- 常用网站配置表单 + 完整 `public/config.js` 编辑器。
- 管理 `public/images` 中的头像、LOGO、背景等固有资源。
- Git、Supabase 与 R2 凭据保存在系统安全存储，不写入仓库。
- 自适应桌面侧栏和移动端底部导航。

## 首次运行

本仓库当前环境没有安装 Flutter SDK，因此平台 Runner 由标准 Flutter 命令生成：

```powershell
flutter create . --project-name starry_note --platforms android,windows,macos,linux
flutter pub get
flutter run -d windows
```

Windows 也可以运行 `./scripts/bootstrap.ps1` 一次性生成平台工程并执行分析与测试。macOS 构建必须在 macOS 上完成。

桌面版 Git 操作依赖系统的 `git` 命令。Android 上可填写由其他 Git 客户端同步到本机的工作区路径；移动端沙箱不提供 Git CLI 时，写作与云服务功能仍可使用，但 commit/push 需要在带 Git 的设备完成。

## 配置提示

- Supabase：查看评论可使用 anon key；删除评论需要拥有 DELETE 权限的 key，通常是 `service_role`。该 key 只保存在本机，绝不能放进博客的 `public/config.js` 或前端产物。
- R2：创建具备目标 Bucket `Object Read & Write` 权限的 API Token，并配置公开自定义域名或 R2.dev URL。
- GitHub/GitLab 私有仓库：使用最小仓库读写权限的 PAT。程序只在 clone/push 子进程中使用它，不修改 remote URL。

## 验证

```powershell
flutter analyze
flutter test
```

核心格式兼容测试位于 `test/`，覆盖 Starry frontmatter、文章索引和 `config.js` 的保留式更新。
