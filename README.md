# leanote-mode
Writing markdown note in emacs with elegant way [leanote](https://leanote.com/[leanote])
and its [open source platform](http://leanote.org/).

## Install
Install it from elpa package source (i.e. [melpa](https://melpa.org/) or [popkit elpa](https://elpa.popkit.org/)).  
```elisp
M-x package-install RET leanote-mode RET
```

## Usage
Add following code to your init(.emacs or init.el anyway) file.
```elisp
(add-hook 'markdown-mode-hook 'leanote)
```
**Note:** Config your own server api if you use youself host(vps) as following  
```elisp
(setq leanote-api-root "youryomain/api")
```

## Hotkey
* **C-c u** update or add new note content to remote.
* **C-c d** delete current leanote.
* **C-c r** rename current leanote.
* **C-c f** find note by note-name.

## Leanote status
The mode line show it status when markdown file is leanote, 
![](images/status.png "mode line status")
What's more, when leanote note is modified local (without push to remote), the mode line show **leanote***
![](images/statusm.png "mode line status modified")
Not login status
![](images/status-unlogin.png "not login status")
Already login status
![](images/status-login.png "already login status")
Need sync with remote
![](images/status-update.png "already login status")

## Leanote log
All logs are recorded in \*Leanote-Log* buffer.

English version readme ends here. Chinese readme provided as follows.

--------------------------------------------------------------------------------

# leanote-mode
leanote-mode是emacs下的一个**minor-mode**，使得你能在emacs下优雅的记笔记。同时，
可采用[leanote](https://leanote.com/)提供的服务保存markdown格式的笔记内容。

## 安装
从elpa的源中进行安装（如[melpa](https://melpa.org/) 或者 [popkit elpa](https://elpa.popkit.org/).）  
```elisp
M-x package-install RET leanote-mode RET
```

## 使用
将下面代码添加到你emacs的启动文件(.emacs 或者 init.el)
```elisp
(add-hook 'markdown-mode-hook 'leanote)
```
如果你是自己部署了leanote的服务，配置自己服务的api
```elisp
(setq leanote-api-root "youryomain/api")
```

## 快捷键
* **C-c u** 更新或者添加当前笔记到服务器
* **C-c d** 删除当前笔记
* **C-c r** 修改当前笔记名
* **C-c f** 按笔记名查找笔记

## leanote状态显示
当一个markdown文件为leanote时，其mode line会显示出来，如下：
![](images/status.png "mode line status")
当一个leanote文件只是在本地修改了，没有同步到远端的时，状态显示为**leanote***，如下：
![](images/statusm.png "mode line status modified")
没有登录时的状态
![](images/status-unlogin.png "not login status")
已经登录时的状态
![](images/status-login.png "already login status")
本地笔记过，需要同步远程笔记的状态
![](images/status-update.png "already login status")

## 操作日志
所有的操作日志被记录在\*Leanote-Log* 这个buffer里。
