# cthulu

一个基于 Godot 4 的桌面宠物放置游戏起始工程。

## 目录说明
- scenes/ ：主场景与界面场景
- scripts/ ：游戏脚本
- assets/characters/ ：角色资源
- assets/ui/ ：界面资源
- assets/audio/ ：音频资源
- builds/windows/ ：导出产物目录

## 当前配置
- 已设置主场景为 res://scenes/Main.tscn
- 已添加 Windows 导出预设
- 已配置基础窗口尺寸与项目元信息

## 后续步骤
1. 安装 Godot 4.x
2. 打开项目文件夹，运行项目
3. 在项目中替换图标、角色资源和主界面内容
4. 使用导出预设生成 Windows 可执行文件
5. 将生成产物上传到 Steam 发布流程

## 启动与测试

Godot 编辑器位于项目的上层目录。不要依赖终端当前所在目录，统一从项目根目录使用启动脚本：

```powershell
# 运行游戏
.\run_game.cmd

# 打开编辑器
.\run_game.cmd -Editor

# 运行全部测试
.\run_tests.cmd
```

VS Code 中也可以运行默认生成任务 `Godot: Run Game`，测试任务为 `Godot: Run Tests`。
脚本会根据自身位置解析项目目录和上层的 Godot 程序，因此从任意工作目录调用都不会启动错项目。
