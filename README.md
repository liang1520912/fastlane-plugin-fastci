
# fastlane-plugin-fastci

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-fastci)

一个集成 iOS 打包脚本与多种自动化操作的 Fastlane 聚合插件。
简单快速的集成，5 分钟即可上手。
配合 Jenkins 实现高度自定义。

---

## 安装方法

1、安装 [python3](https://www.python.org/downloads/macos/)

2、安装 [homebrew](https://brew.sh/)

3、安装并初始化 [fastlane](https://docs.fastlane.tools/getting-started/ios/setup/)

4、添加插件 ` fastlane add_plugin fastci `

5、更新插件 ` fastlane update_plugins `

---

## 使用方法

参考 [` Fastfile `](fastlane/Fastfile) 和 [` .env.default `](fastlane/.env.default) 替换项目内 fastlane 文件夹下文件；
项目根目录新建 ` PACKAGE_FILE_FOLDER_NAME ` 配置对应名字文件夹，将描述文件、p12 证书、p8 密钥等文件放入该文件夹下；
然后终端进入项目根目录即可使用 ` fastlane `

如果是同一个 xcworkspace 多 xcodeproj 的情况，可以采用多配置文件的方式。同样也是参考 [` .env.default `](fastlane/.env.default) 根据多个 xcodeproj 创建多个配置文件 ` .env.project1 ` 、 ` .env.project2 `，注意文件的隐藏扩展，名字不能是 ` .env.project1.default `；
不同的配置文件配置不同的 ` PROJECT_NAME `；
执行的时候指定环境文件 ` fastlane --env project1 package ` 来运行


### 使用后会在项目根目录生成文件夹

可以自行在 ` .gitignore ` 中设置忽略等级 

```
fastlane_cache/ # 插件缓存文件夹
├── build_logs/ # 编译日志
├── html/ # 各种检查报告
├── temp/ # 临时文件
├── build_cache.txt # build 自动递增缓存
└── commit_cache.txt # git commit 缓存
```

## 支持功能与使用示例

### 1. 自动打包
功能：自动编译并导出 ipa 包，支持多种打包方式和集成多项检查。
生成完的 ipa 会放在桌面上，非 ` app-store ` 配置了蒲公英或 fir 参数会自动上传蒲公英或 fir。` app-store ` 和 ` testFlight ` 配置了商店参数会自动上传商店。
配置了 Sentry 参数会自动上传符号表。

` build `: 不指定的话内部有递增逻辑，格式为 ` 20250905.15（日期+当天包的次数） `

` version `: 在 Xcode13 之后创建的项目，不再支持脚本修改。需要兼容请在 ` Build settings ` 中将 ` GENERATE_INFOPLIST_FILE ` 设置为 ` NO `

其他参数可以使用 ` fastlane action package ` 查看

```ruby
package(
	configuration: "Debug", # 编译环境 Release/Debug
	export_method: "development", # 打包方式 ad-hoc, enterprise, app-store, development, testFlight
	version: nil, # 指定 version
	build: nil, # 指定 build 号
	is_analyze_swiftlint: false, # 是否代码分析
	is_detect_duplicity_code: false, # 是否检测重复代码
	is_detect_unused_code: false, # 是否检测未使用代码
	is_detect_unused_image: false, # 是否检测未使用图片
	changelog: options[:changelog], # fir 更新日志
    release_notes: options[:release_notes], # 配合 jenkins 传参上传 appstore 格式为 { \"zh-Hans\": \"修复问题\", \"en-US\": \"bugfix\"} JSON 字符串 
	is_notice_dingding: options[:is_notice_dingding], # 配置钉钉token了，通过该参数控制是否发送通知
	# app-store 时可传入资源发布配置；上传 IPA 后自动更新资源、选择构建并按配置提交审核
	app_store_resources_config_path: "fastlane/app_store_resources.json"
)
```

当 `export_method` 为 `app-store` 且配置了 `app_store_resources_config_path` 时，完整流程为：打包并上传 IPA、上传变更的 metadata 和截图、按精确的版本号和 Build Number 选择构建；只有 `submit_for_review` 明确设置为 `true` 时才提交审核。该参数未配置时，`package` 保持原有行为。

当配置 `upload_metadata_on_new_version: true`（默认值）时，`package` 会在上传 IPA 前检查目标 App Store 版本。如果目标版本尚不存在，即使 `metadata_changed` 为 `false`，也会强制上传 metadata，适用于推广文案在多个版本中保持不变但每个新版本都必须填写的场景。

### 2. SwiftLint 静态代码分析
功能：依赖 ` SwiftLint ` 对项目代码进行静态分析，生成分析报告。
使用前需要参考自定义 [` .swiftlint.yml `](/.swiftlint.yml) 文件，并将该文件放到项目根目录。

` commit_hash `: 上一次提交哈希, 会比较该哈希到最新哈希之间的文件

```ruby
analyze_swiftlint(
	is_all: true, # 是否检查所有文件，默认 true
	configuration: "Debug", # 构建配置，Debug/Release
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

TestFlight 打包时可以单独配置 TestFlight Build Number 和测试内容。该 Build Number 会写入 TestFlight IPA，并在上传后按 `App Version + TestFlight Build Number` 等待和校验，不会使用 App Store 发布流程的构建选择逻辑：

```ruby
package(
  export_method: "testFlight",
  testflight_config_path: "fastlane/testflight_release.json"
)
```

也可以直接传入 `testflight_build_number`、`testflight_changelog` 等参数，不使用配置文件。

`fastlane/testflight_release.json` 示例：

```json
{
  "app_identifier": "com.example.app",
  "app_version": "7.0.0",
  "testflight_build_number": "2026081302",
  "changelog": "请重点测试登录、消息和支付流程。",
  "api_key_path": "/path/to/api-key.json",
  "wait_for_build_processing": true,
  "build_processing_timeout": 3600,
  "build_processing_poll_interval": 30,
  "build_processing_retry_limit": 3,
  "build_processing_retry_interval": 15,
  "distribute_external": false,
  "notify_external_testers": false
}
```

`distribute_external` 和 `notify_external_testers` 默认均为 `false`，当前不会自动分发或通知外部测试人员。TestFlight 上传成功后，插件会确认指定的 TestFlight 构建已处理完成；找不到对应构建或构建处理失败时，Jenkins 构建会失败。

### 3. 检测重复代码
功能：检测项目中的重复代码，生成分析报告。
使用前需要参考自定义 [` .periphery.yml `](/.periphery.yml) 文件，并将该文件放到项目根目录。

` commit_hash `: 上一次提交哈希, 会比较该哈希到最新哈希之间的文件

```ruby
detect_duplicity_code(
	is_all: true, # 是否检查所有文件，默认 true
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 4. 检测未使用代码
功能：检测项目中未被使用的代码，生成分析报告。
默认只支持 ` Debug `，需要支持 ` Release ` 请在 ` Build settings ` 中将 ` Enable Index-While-Building Functionality ` 设置为 ` Yes `。

```ruby
detect_unused_code(
	configuration: "Debug" # 构建配置，Debug/Release
)
```

### 5. 检测未使用图片资源
功能：检测项目中未被使用的图片资源，生成分析报告。

```ruby
detect_unused_image(
    exclude: nil # 要排除的路径，多个路径用逗号分隔。默认会排除 Carthage 和 Pods 目录
)
```

### 6. App Store Connect 资源管理
功能：校验 metadata 和截图目录，按资源变更结果上传对应资源；资源缺失时可以从 App Store Connect 下载。
该 action 只上传资源，不上传 IPA，不会改变已有 `package` 和 `upload_store` 的默认行为。

```ruby
app_store_resources(
  config_path: "fastlane/app_store_resources.json"
)
```

`fastlane/app_store_resources.json` 示例：

```json
{
  "app_identifier": "com.example.app",
  "app_version": "1.0.0",
  "metadata_path": "fastlane/metadata",
  "screenshots_path": "fastlane/screenshots",
  "metadata_changed": true,
  "screenshots_changed": true,
  "download_missing_metadata": true,
  "download_missing_screenshots": true,
  "use_live_version": false,
  "api_key_path": "/path/to/api-key.json",
  "select_build": true,
  "build_number": "2026081301",
  "wait_for_build_processing": true,
  "build_processing_timeout": 3600,
  "build_processing_poll_interval": 30,
  "build_processing_retry_limit": 3,
  "build_processing_retry_interval": 15,
  "submit_for_review": false,
  "automatic_release": false
}
```

也可以在调用 action 时覆盖配置文件中的单个值，显式参数优先：

```ruby
app_store_resources(
  config_path: "fastlane/app_store_resources.json",
  metadata_changed: false,
  screenshots_changed: true
)
```

参数说明：

- `config_path`：JSON 配置文件路径。
- `app_identifier`：App Store Connect App 的 Bundle ID，必须通过配置文件或 action 参数提供。
- `app_version`：要更新的 App Store 版本号，可选。
- `metadata_path`：metadata 目录，默认 `fastlane/metadata`。
- `screenshots_path`：截图目录，默认 `fastlane/screenshots`。
- `metadata_changed`：为 `true` 时校验并上传 metadata；没有变化时设置为 `false`。
- `screenshots_changed`：为 `true` 时校验并上传截图；没有变化时设置为 `false`。
- `upload_metadata_on_new_version`：目标 App Store 版本不存在时是否强制上传 metadata，默认 `true`。
- `download_missing_metadata`：metadata 目录为空时从 App Store Connect 下载。
- `download_missing_screenshots`：截图目录为空时从 App Store Connect 下载。
- `use_live_version`：下载截图时使用线上版本；默认使用可编辑版本。
- `api_key_path` 或 `api_key`：App Store Connect API Key，二选一，也可以复用 Fastlane 已设置的 API token。
- `select_build`：是否选择指定的 App Store Connect 构建，默认 `false`。
- `build_number`：要选择的精确构建号。开启 `select_build` 或 `submit_for_review` 时必须填写，不会自动猜测最新构建。
- `wait_for_build_processing`：选择构建前是否等待 Apple 处理完成，默认 `true`。
- `build_processing_timeout` 和 `build_processing_poll_interval`：等待构建处理的总超时时间和轮询间隔，单位均为秒。
- `build_processing_retry_limit` 和 `build_processing_retry_interval`：查询构建状态遇到 SSL、连接中断或超时时的最大重试次数和重试间隔，默认分别为 `3` 和 `15` 秒；重试不会超过总超时时间。
- `submit_for_review`：是否提交审核，默认 `false`。提交审核前会先选择指定构建。
- `automatic_release`：审核通过后是否自动发布，默认 `false`；只在 `submit_for_review` 为 `true` 时生效。
- `submission_information`：提交审核所需信息，例如 `{"export_compliance_uses_encryption": false}`。

只更新资源、不上传 IPA 时，直接调用 `app_store_resources`。完整的打包发布流程则在 `package(export_method: "app-store")` 中传入 `app_store_resources_config_path`。资源变化开关可按实际情况配置：

```json
{
  "metadata_changed": true,
  "screenshots_changed": false,
  "select_build": true,
  "submit_for_review": false
}
```

其中截图没有变化时不会上传截图，但仍然可以选择本次 IPA 对应的构建。

---

## 贡献与支持

如需更多帮助或贡献，请提交 Issue 或 PR。
