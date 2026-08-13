require 'fastlane/action'
include Fastlane::Helper

module Fastlane
  module Actions
    # 校验并上传 App Store Connect metadata 和截图
    class AppStoreResourcesAction < Action
      def self.run(params)
        params = AppStoreResourcesHelper.load_params(params)
        UI.user_error!('必须配置 App Store Connect App 的 Bundle ID') if params[:app_identifier].to_s.empty?

        metadata_path = AppStoreResourcesHelper.resource_path(
          params[:metadata_path],
          'metadata 目录',
          create: params[:download_missing_metadata],
          required: params[:metadata_changed] || params[:download_missing_metadata]
        )
        screenshots_path = AppStoreResourcesHelper.resource_path(
          params[:screenshots_path],
          '截图目录',
          create: params[:download_missing_screenshots],
          required: params[:screenshots_changed] || params[:download_missing_screenshots]
        )

        AppStoreResourcesHelper.download_missing(params, metadata_path, screenshots_path)

        if params[:metadata_changed] || params[:screenshots_changed]
          AppStoreResourcesHelper.validate_metadata(metadata_path) if params[:metadata_changed]
          AppStoreResourcesHelper.validate_screenshots(screenshots_path) if params[:screenshots_changed]

          UI.message('*************| 开始上传 App Store Connect 资源 |*************')
          other_action.upload_to_app_store(
            AppStoreResourcesHelper.resource_options(params, metadata_path, screenshots_path)
          )
          UI.success('App Store Connect 资源上传完成')
        else
          UI.message('*************| 没有 metadata 或截图变更，跳过资源上传 |*************')
        end

        if params[:select_build] || params[:submit_for_review]
          AppStoreResourcesHelper.select_build(params)
        end

        if params[:submit_for_review]
          UI.message('*************| 开始提交 App Store 审核 |*************')
          other_action.upload_to_app_store(AppStoreResourcesHelper.review_options(params))
          UI.success('App Store 审核提交完成')
        end
      end

      def self.description
        '校验并上传 App Store Connect metadata 和截图'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :config_path,
            description: '资源发布 JSON 配置文件路径，显式参数优先于配置文件',
            optional: true,
            default_value: nil,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("资源配置文件不存在: #{value}") unless File.file?(File.expand_path(value))
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_identifier,
            description: 'App Store Connect App 的 Bundle ID',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :app_version,
            description: '要更新的 App Store 版本号',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_path,
            description: 'metadata 目录路径',
            optional: true,
            default_value: 'fastlane/metadata',
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :screenshots_path,
            description: '截图目录路径',
            optional: true,
            default_value: 'fastlane/screenshots',
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :metadata_changed,
            description: '是否上传 metadata',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :screenshots_changed,
            description: '是否上传截图',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :download_missing_metadata,
            description: 'metadata 缺失时是否从 App Store Connect 下载',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :download_missing_screenshots,
            description: '截图缺失时是否从 App Store Connect 下载',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :use_live_version,
            description: '下载截图时是否使用线上版本',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key,
            description: 'App Store Connect API Key Hash',
            optional: true,
            sensitive: true,
            type: Hash,
            conflicting_options: [:api_key_path]
          ),
          FastlaneCore::ConfigItem.new(
            key: :api_key_path,
            description: 'App Store Connect API Key JSON 文件路径',
            optional: true,
            type: String,
            conflicting_options: [:api_key],
            verify_block: proc do |value|
              UI.user_error!("API Key JSON 不存在: #{value}") unless File.file?(value)
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :username,
            description: 'Apple ID 用户名，仅在未提供 API Key 时使用',
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :platform,
            description: 'App Store Connect 平台',
            optional: true,
            default_value: 'ios',
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :sync_screenshots,
            description: '是否让远端截图与本地截图同步',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :overwrite_screenshots,
            description: '上传前是否清空远端截图',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :submit_for_review,
            description: '上传资源后是否提交审核',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :automatic_release,
            description: '审核通过后是否自动发布',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :select_build,
            description: '是否按 app_version 和 build_number 自动选择构建',
            optional: true,
            default_value: false,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_number,
            description: '要选择的精确 Build Number',
            optional: true,
            default_value: nil,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :wait_for_build_processing,
            description: '选择构建前是否等待 App Store Connect 处理完成',
            optional: true,
            default_value: true,
            type: Boolean
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_processing_timeout,
            description: '等待构建处理完成的超时时间，单位秒',
            optional: true,
            default_value: 3600,
            type: Integer
          ),
          FastlaneCore::ConfigItem.new(
            key: :build_processing_poll_interval,
            description: '查询构建处理状态的时间间隔，单位秒',
            optional: true,
            default_value: 30,
            type: Integer
          ),
          FastlaneCore::ConfigItem.new(
            key: :submission_information,
            description: 'deliver 提交审核信息，例如出口合规声明',
            optional: true,
            default_value: nil,
            type: Hash
          ),
          FastlaneCore::ConfigItem.new(
            key: :force,
            description: '是否跳过 HTML 预览确认',
            optional: true,
            default_value: true,
            type: Boolean
          )
        ]
      end

      def self.is_supported?(platform)
        platform == :ios
      end

      def self.category
        :production
      end
    end
  end
end
