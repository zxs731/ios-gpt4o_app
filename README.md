# ios-gpt4o_app
# 本代码为基于GPT-4o可离线唤醒的语音助手，由于使用Azure OpenAI国内可无需VPN和网络代理直接使用。同时使用了最新的微软流式TTS，语音效果和速度体验相当不错。

## 实际效果视频：
【GPT-4o实现的原生APP，基于object-c，无需VP N网络代理，语音对话采用微软Speech，真人版AI TTS】 https://www.bilibili.com/video/BV1NJ4m1g7Pf/?share_source=copy_web&vd_source=245c190fe77b507d57968a57b3d6f9cf
## 教程视频：
【自制GPT-4o可离线唤醒的iOS APP，无需VPN，语音效果超ChatTTS，无需object-c编程技能，用AI开发AI过程详解】 https://www.bilibili.com/video/BV1sT421v77a/?share_source=copy_web&vd_source=245c190fe77b507d57968a57b3d6f9cf

## 以下为搭建步骤，可参考视频使用：
### 1 下载本套源码
### 2 用XCode打开这个工程
### 3 下载 MicrosoftCognitiveServicesSpeech.xcframework （https://aka.ms/csspeech/macosbinary） 解压放到本项目根目录
### 4 在XCode里添加MicrosoftCognitiveServicesSpeech.xcframework的引用
### 5 替换ViewController.m文件中TTS参数和OpenAI的参数，搜索替换“xxx”值的部分
### 6 XCode点击Run
