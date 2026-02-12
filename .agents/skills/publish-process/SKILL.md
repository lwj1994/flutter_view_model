---
name: Publish Process
description: Workflow for publishing view_model packages (annotation, generator, view_model) in the correct order.
---

# Publish Process

1. 先更新版本号。只改动 version: xxx 。其他的依赖版本不要改
2. view_model_generator 和 view_model 需要更新 view_model_annotation 的版本
2. 始终保持 "stack_trace: " 版本为空， “meta” 版本为空
2. 编写 changelog
3. 按顺序发布 
	a. view_model_annotation
	b. view_model_generator
	c. view_model
4. 发布代码： fd pub publish  然后执行后等待一会 输入 y
4. 发布 view_model_annotation 后等待 5分钟，然后发布 view_model_generator 和 view_model
5. 发布结束后，执行 git add . && git commit -m  "publish version:xx"
