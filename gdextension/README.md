# GDExtension 原生后端（Flecs）

`GF_EcsWorld` 的 NATIVE 存储后端（性能路线图 §1.6 第一步「存储 + 查询下沉」）。
纯 GDScript 使用方**无需**本目录；需要原生后端时编译后 opt-in 启用。

## 前置

- Godot 4.7+
- Python 3 + SCons（`pip3 install scons`）
- C/C++ 编译器（macOS 用 Xcode CLT 的 clang）

## 编译

```bash
cd gdextension
git submodule update --init   # 首次：拉取 godot-cpp
scons target=template_debug   # 产物输出到 ../addons/gf_ecs_native/bin/
```

产物 + `../addons/gf_ecs_native/gf_ecs_native.gdextension` 由 Godot 启动时
自动加载，无需手动配置。验证：

```bash
godot --headless --path .. -s res://gdextension/probe_smoke.gd
```

## 目录

```text
gdextension/
├── SConstruct          # godot-cpp api_version=4.7，输出到 ../addons/
├── godot-cpp/          # submodule（godotengine/godot-cpp master，10.x）
├── vendor/flecs/       # Flecs amalgamated（flecs.c + flecs.h，MIT）
└── src/
    ├── gf_ecs_probe.cpp          # GF_EcsProbe：Flecs 版本诊断 + 边界测量目标
    └── gf_ecs_native_world.cpp   # GF_EcsNativeWorld：Flecs world 封装
```

## 分发策略（§1.6，2026-08 修订：预编译随仓库分发）

**NATIVE 后端使用方零编译链门槛**：预编译二进制随仓库分发
（`../addons/gf_ecs_native/bin/`，已提交 git），拉取框架即自动加载——
Godot 4.x 系列内 GDExtension ABI 稳定（`compatibility_minimum=4.7`），
4.7+ 版本直接可用。当前平台覆盖：macOS universal（arm64+x86_64）。
其他平台按需补位（未提供二进制的平台自动降级为纯 GDScript 后端，
框架功能不受影响）。

**需要编译链的场景**：
1. §1.7 原生系统开发（自己的 C++ 系统代码必须编进 dylib）；
2. 需要其他平台/自定义构建。

编译步骤见上文「编译」。二进制更新流程：框架升级 Godot 大版本或
Flecs 版本时，重新编译并提交 `addons/gf_ecs_native/bin/`。

## 版本对应

| 组件 | 版本 |
|------|------|
| godot-cpp | master（10.x，内置 extension_api-4-7.json） |
| Flecs | v4.1.6（2026-06-29） |
| Godot | 4.7+ |
