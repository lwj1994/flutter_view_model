---
trigger: always_on
---

1. 先更新版本号。只改动 version: xxx 。其他的依赖版本不要改
2. 始终保持   `annotation:`  版本为空
2. 编写 changelog
3. 按顺序发布 
	a. annotation
	b. genarator
	c. view_model
4. 发布代码： fd pub publish   执行后等待一会 输入 y
5. 发布结束后，执行 git add . && git commit -m  "publish version:xx"