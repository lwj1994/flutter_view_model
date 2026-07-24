#!/bin/bash

# DevTools Extension Build Script
# 自动构建并复制web资源到目标目录

set -e  # 遇到错误时退出

echo "🔨 Building DevTools Extension..."

# 进入扩展包目录
cd packages/view_model_devtools_extension

# 清理之前的构建
echo "🧹 Cleaning previous build..."
rm -rf build/web

# 构建web版本
echo "📦 Building web assets..."
puro flutter build web --release

# 检查构建是否成功
if [ ! -d "build/web" ]; then
    echo "❌ Build failed: build/web directory not found"
    exit 1
fi

# 创建目标目录
echo "📁 Creating target directory..."
rm -rf ../view_model/extension/devtools/build
mkdir -p ../view_model/extension/devtools/build

# 复制构建产物
echo "📋 Copying build artifacts..."
cp -r build/web/* ../view_model/extension/devtools/build/

# 验证复制结果
if [ -f "../view_model/extension/devtools/build/index.html" ]; then
    echo "✅ Build and copy completed successfully!"
    echo "📍 Files copied to: packages/view_model/extension/devtools/build/"
else
    echo "❌ Copy failed: index.html not found in target directory"
    exit 1
fi

echo "🎉 DevTools extension is ready!"
