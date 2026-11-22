class TrackpadMedia < Formula
  desc "macOS trackpad multi-finger gestures for media（触摸板手势切歌调音量）"
  homepage "https://github.com/hewuan-git/macos-trackpad-gestures"
  url "https://github.com/hewuan-git/macos-trackpad-gestures/archive/refs/tags/v1.0.tar.gz"
  sha256 "88e98b1a71a76b76d898afb346d8d9a7a0c8f7f8e0c5a6de20336d8a92ec12df"
  license "MIT"

  # 只用到系统框架：CoreFoundation / CoreAudio / IOKit / MultitouchSupport + clang
  # 所以没有 depends_on，也不需要 Xcode，命令行工具就够了。最低 macOS 12
  # （kIOMainPortDefault 和 kAudioObjectPropertyElementMain 都是 12 才有的）。

  def install
    system ENV.cc, "-O2", "-fblocks", "-Wall", "-Wno-deprecated-declarations",
           "-o", "trackpad-media", "main.c",
           "-framework", "CoreFoundation", "-framework", "CoreAudio",
           "-framework", "IOKit", "-ldl"

    # 装成 .app 而不是裸二进制：TCC 授权列表里显示的是 App 名字（Trackpad Media），
    # 裸二进制会以全小写的 trackpad-media 出现，和 App 那条长得很像但拨了没用。
    app = buildpath/"TrackpadMedia.app"
    (app/"Contents/MacOS").mkpath
    (app/"Contents/Info.plist").write <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleExecutable</key><string>trackpad-media</string>
          <key>CFBundleIdentifier</key><string>com.local.trackpad-media</string>
          <key>CFBundleName</key><string>Trackpad Media</string>
          <key>CFBundlePackageType</key><string>APPL</string>
          <key>CFBundleShortVersionString</key><string>#{version}</string>
          <key>LSUIElement</key><true/>
      </dict>
      </plist>
    PLIST
    (app/"Contents/MacOS").install "trackpad-media"

    system "codesign", "-s", "-", "--force", app

    prefix.install app
    bin.install_symlink "#{prefix}/TrackpadMedia.app/Contents/MacOS/trackpad-media" => "trackpad-media"
    (bin/"trackpad-media-setup").write <<~BASH
      #!/bin/bash
      # 打开 / 关闭 trackpad-media 的登录自启（Homebrew 版）。参数含义: --help
      set -euo pipefail

      APP="#{HOMEBREW_PREFIX}/opt/trackpad-media/TrackpadMedia.app"
      BIN="$APP/Contents/MacOS/trackpad-media"
      LABEL="com.user.trackpad-media"
      PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
      LOG_DIR="$HOME/Library/Application Support/trackpad-media"
      LOG="$LOG_DIR/run.log"

      if [ ! -x "$BIN" ]; then
          echo "找不到 $BIN"
          exit 1
      fi

      if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
          echo "用法: trackpad-media-setup [闸门] [切歌方式] [横滑行程] [几指] [轻点]"
          echo "      trackpad-media-setup --off"
          echo "  闸门: audio(默认，有进程在送音频才生效) | media(只认 MediaRemote) | none(不判定)"
          echo "  切歌: key(默认，模拟硬件媒体键) | mr(只发 MediaRemote 命令) | both"
          echo "  行程: 0.04~0.9，越小越轻就能切歌，默认 0.10"
          echo "  几指: 2~5，默认 3；系统的「N 指轻扫」算 N 指及以上，要和系统错开"
          echo "  轻点: on(默认，N 指轻点=播放/暂停) | off"
          echo "二进制自己的调试模式（--check / --watch / --test）：trackpad-media --help"
          exit 0
      fi

      if [ "${1:-}" = "--off" ]; then
          launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
          [ -f "$PLIST" ] && mv "$PLIST" "$PLIST.disabled"
          echo "已停止并取消自启，程序、plist(改名 .disabled)、日志都保留。"
          echo "恢复: trackpad-media-setup audio key 0.10 3 on"
          exit 0
      fi

      GATE="${1:-audio}"
      TRACK="${2:-key}"
      SWIPE="${3:-0.10}"
      FINGERS="${4:-3}"
      TAP="${5:-on}"
      case "$GATE" in media|audio|none) ;; *) echo "闸门只能是 media|audio|none"; exit 2 ;; esac
      case "$TRACK" in mr|key|both) ;; *) echo "切歌只能是 mr|key|both"; exit 2 ;; esac
      case "$SWIPE" in *.*) ;; *) echo "行程要写成小数，比如 0.10"; exit 2 ;; esac
      case "$FINGERS" in 2|3|4|5) ;; *) echo "几指只能是 2|3|4|5"; exit 2 ;; esac
      case "$TAP" in on|off) ;; *) echo "轻点只能是 on|off"; exit 2 ;; esac

      # 系统的"N 指轻扫"把 N 指及以上都算进去，这一档还被系统占着就会撞车
      KEYS=""
      if [ "$FINGERS" = 3 ]; then
          KEYS="TrackpadThreeFingerHorizSwipeGesture TrackpadThreeFingerVertSwipeGesture TrackpadThreeFingerDrag"
          [ "$TAP" = on ] && KEYS="$KEYS TrackpadThreeFingerTapGesture"
      elif [ "$FINGERS" = 4 ]; then
          KEYS="TrackpadFourFingerHorizSwipeGesture TrackpadFourFingerVertSwipeGesture"
      fi
      for k in $KEYS; do
          v="$(defaults read com.apple.AppleMultitouchTrackpad "$k" 2>/dev/null || echo 0)"
          if [ "$v" != "0" ]; then
              echo "警告：系统里 $k = $v，$FINGERS 指这一档还被系统占着，会和手势撞车"
          fi
      done

      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
      cat > "$PLIST" <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>$LABEL</string>
          <key>ProgramArguments</key>
          <array>
              <string>$BIN</string>
              <string>--run</string>
              <string>--gate</string>
              <string>$GATE</string>
              <string>--track</string>
              <string>$TRACK</string>
              <string>--swipe</string>
              <string>$SWIPE</string>
              <string>--fingers</string>
              <string>$FINGERS</string>
              <string>--tap</string>
              <string>$TAP</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <dict>
              <key>SuccessfulExit</key>
              <false/>
          </dict>
          <key>ThrottleInterval</key>
          <integer>10</integer>
          <key>StandardOutPath</key>
          <string>$LOG</string>
          <key>StandardErrorPath</key>
          <string>$LOG</string>
      </dict>
      </plist>
      EOF

      i=0
      until launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null; do
          i=$((i+1))
          if [ "$i" -ge 5 ]; then echo "任务装不上，重跑一次这个脚本"; exit 1; fi
          sleep 2
      done
      sleep 2
      PID="$(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | sed -n 's/.*pid = \\([0-9]*\\).*/\\1/p' | head -1)"
      echo "--- 已启动：闸门=$GATE 切歌=$TRACK 横滑行程=$SWIPE 用=$FINGERS 指 轻点=$TAP  进程号=${PID:-未启动} ---"
      echo
      echo "调音量不用授权，已经能用了。切歌和播放/暂停要手动加一次授权："
      echo "  1. 打开 系统设置 → 隐私与安全性 → 设备控制和数据访问（旧系统叫辅助功能）"
      echo "     open \\"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\\""
      echo "  2. 列表里找到 Trackpad Media，把开关拨到开；没有就用 + 添加：$APP"
      echo "  3. 拨完必须重启一次进程才认："
      echo "     launchctl kickstart -k gui/\\$(id -u)/$LABEL"
      echo "  4. 验证：kill -USR1 \\$(pgrep -f TrackpadMedia.app) 然后 tail -6 \\"$LOG\\""
      echo "     看到「自检通过」就成了"
      echo
      echo "日志: $LOG"
      echo "停止: trackpad-media-setup --off"
    BASH
  end

  def caveats
    <<~EOS
      手势要生效还差一步手动授权（Apple 不允许任何安装器代劳）：
        系统设置 → 隐私与安全性 → 设备控制和数据访问 → 打开 Trackpad Media
      拨完开关必须重启进程才认：
        launchctl kickstart -k gui/$(id -u)/com.user.trackpad-media

      启动/停止：
        trackpad-media-setup audio key 0.10 3 on
        trackpad-media-setup --off

      brew upgrade / reinstall 会重新编译，ad-hoc 签名跟着变，之前那条授权会失效：
        tccutil reset Accessibility com.local.trackpad-media
      然后在列表里删掉旧条目、重新添加一次。
    EOS
  end

  test do
    # --check 只读状态，不发按键、不动音量
    out = shell_output("#{bin}/trackpad-media --check 2>&1")
    assert_match "MultitouchSupport", out
    assert_match "媒体键通路", out
  end
end
