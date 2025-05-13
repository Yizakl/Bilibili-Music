# Bilibili Music

一个简洁、功能齐全的B站视频音频提取播放器，支持Windows平台，基于Flutter开发。

## 🎵 主要功能

- 🔍 支持BV号和B站视频URL链接搜索
- 🎧 强大的音频播放器，支持后台播放
- 💾 支持缓存管理和音频下载
- 🌙 支持深色模式和浅色模式切换
- 🔄 使用mir6 API流畅播放B站视频音频


## 🚀 开始使用

### 系统要求

- Windows 10/11 64位系统

### 安装方法

1. 从[Release页面](https://github.com/Yizakl/Bilibili-Music/releases)下载最新版本
2. 解压文件到任意位置
3. 运行 `bilibili_music.exe` 开始使用

如果你老急了，迫不及待要食用我的104+问题的版本，你可以使用 [Actions内构建的版本](https://github.com/Yizakl/Bilibili-Music/actions)

## 💻 开发者指南

### 环境设置

1. 安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)
2. 确保Flutter支持Windows平台：`flutter config --enable-windows-desktop`
3. 克隆仓库：`git clone https://github.com/Yizakl/Bilibili-Music.git`
4. 进入项目目录：`cd Bilibili-Music`
5. 获取依赖：`flutter pub get`
6. 运行应用：`flutter run -d windows`

### 构建应用

构建Windows应用程序：

```bash
flutter build windows --release
```

### 项目结构

```
lib/
├── app/                  # 应用程序入口和配置
├── core/                 # 核心服务和工具
│   ├── models/           # 数据模型
│   ├── services/         # 服务类 
│   └── utils/            # 工具函数
├── features/             # 功能模块
│   ├── home/             # 首页功能
│   ├── player/           # 播放器功能
│   ├── search/           # 搜索功能
│   └── settings/         # 设置功能
└── main.dart             # 程序入口
```

## 📝 注意事项

- 本应用仅用于学习和研究Flutter开发，不用于任何商业用途
- 请尊重B站版权，不要下载或传播未经授权的内容
- 所有B站视频内容的版权归原作者所有

## 🔄 更新日志

- **v1.0.0** - 初始版本发布
  - 支持BV号和URL链接搜索B站视频
  - 集成音频播放器
  - 基本设置功能

## 📱 支持平台

- ✅ Windows
- 🚧 Android (C盘被VS2022占满了)
- ✅ iOS (后台播放未完善)
- 🚧 macOS (我的黑苹果没显卡驱动不想打开)
- 🚧 Linux (换成黑苹果了)

## 🤝 贡献

欢迎贡献代码、提出问题或建议！请通过Issues和Pull Requests参与项目开发。

## 📄 许可证

本项目采用 [MIT许可证](LICENSE) 进行授权。
