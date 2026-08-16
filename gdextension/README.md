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

## 分发策略（§1.6）

框架保持「Git 仓库纯代码」分发：C++ 源码随仓库走（submodule + vendored
amalgamated），使用方本地编译，**不承诺预编译二进制**（跨 Godot 版本 ABI
不稳定）。不引入编译链的使用方留在 GDScript 后端（NATIVE 本身 opt-in）。

## 版本对应

| 组件 | 版本 |
|------|------|
| godot-cpp | master（10.x，内置 extension_api-4-7.json） |
| Flecs | v4.1.6（2026-06-29） |
| Godot | 4.7+ |
