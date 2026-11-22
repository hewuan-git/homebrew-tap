# homebrew-tap

Homebrew tap for [macos-trackpad-gestures](https://github.com/hewuan-git/macos-trackpad-gestures) —
在 macOS 上用触摸板多指手势控制媒体：横滑切歌、竖滑调音量、轻点播放/暂停。

```sh
brew tap hewuan-git/tap
brew install trackpad-media
trackpad-media-setup          # 注册成登录自启；参数见 --help 和主仓库 README
```

装完还差一步手动授权（Apple 不允许任何安装器代劳），说明在主仓库 README 的「必须手动授权一次」/ "One permission you must grant by hand"。

- 公式：[Formula/trackpad-media.rb](Formula/trackpad-media.rb)
- 源码、文档、参数含义：https://github.com/hewuan-git/macos-trackpad-gestures （本 tap 只是把它编成 `.app` 并生成开机自启脚本）
- 停止：`trackpad-media-setup --off`（只停不自启，文件和日志都保留）
- 要求 macOS 12 以上、有触摸板；只需要命令行工具里的 clang，不需要 Xcode 或 Homebrew 以外的依赖。

`brew upgrade` 会重新编译，ad-hoc 签名跟着变，之前那条授权会失效——在主仓库 README 里写了怎么清掉重加。
